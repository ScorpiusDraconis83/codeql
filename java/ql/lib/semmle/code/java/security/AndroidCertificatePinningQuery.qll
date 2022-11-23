/** Definitions for the Android Missing Certificate Pinning query. */

import java
import semmle.code.xml.AndroidManifest
import semmle.code.java.dataflow.TaintTracking
import HttpsUrls

/** An Android Network Security Configuration XML file. */
class AndroidNetworkSecurityConfigFile extends XmlFile {
  AndroidNetworkSecurityConfigFile() {
    exists(AndroidApplicationXmlElement app, AndroidXmlAttribute confAttr, string confName |
      confAttr.getElement() = app and
      confAttr.getValue() = "@xml/" + confName and
      this.getRelativePath().matches("%res/xml/" + confName + ".xml") and
      this.getARootElement().getName() = "network-security-config"
    )
  }
}

/** Holds if this database is of an Android application. */
predicate isAndroid() { exists(AndroidManifestXmlFile m) }

/** Holds if the given domain name is trusted by the Network Security Configuration XML file. */
private predicate trustedDomainViaXml(string domainName) {
  exists(
    AndroidNetworkSecurityConfigFile confFile, XmlElement domConf, XmlElement domain,
    XmlElement trust
  |
    domConf.getFile() = confFile and
    domConf.getName() = "domain-config" and
    domain.getParent() = domConf and
    domain.getName() = "domain" and
    domain.getACharactersSet().getCharacters() = domainName and
    trust.getParent() = domConf and
    trust.getName() = ["trust-anchors", "pin-set"]
  )
}

/** Holds if the given domain name is trusted by an OkHttp `CertificatePinner`. */
private predicate trustedDomainViaOkHttp(string domainName) {
  exists(CompileTimeConstantExpr domainExpr, MethodAccess certPinnerAdd |
    domainExpr.getStringValue().replaceAll("*.", "") = domainName and // strip wildcard patterns like *.example.com
    certPinnerAdd.getMethod().hasQualifiedName("okhttp3", "CertificatePinner$Builder", "add") and
    DataFlow::localExprFlow(domainExpr, certPinnerAdd.getArgument(0))
  )
}

/** Holds if the given domain name is trusted by some certifiacte pinning implementation. */
predicate trustedDomain(string domainName) {
  trustedDomainViaXml(domainName)
  or
  trustedDomainViaOkHttp(domainName)
}

/**
 * Holds if `setSocketFactory` is a call to `HttpsURLConnection.setSSLSocketFactory` or `HttpsURLConnection.setDefaultSSLSocketFactory`
 * that uses a socket factory derrived from a `TrustManager`.
 * `default` is true if the default SSL socket factory for all URLs is being set.
 */
private predicate trustedSocketFactory(MethodAccess setSocketFactory, boolean default) {
  exists(MethodAccess getSocketFactory, MethodAccess initSslContext, string methodName |
    setSocketFactory
        .getMethod()
        .getASourceOverriddenMethod*()
        .hasQualifiedName("javax.net.ssl", "HttpsURLConnection", methodName) and
    (
      default = true and methodName = "setDefaultSSLSocketFactory"
      or
      default = false and methodName = "setSSLSocketFactory"
    ) and
    initSslContext.getMethod().hasQualifiedName("javax.net.ssl", "SSLContext", "init") and
    getSocketFactory
        .getMethod()
        .getASourceOverriddenMethod*()
        .hasQualifiedName("javax.net.ssl", "SSLContext", "getSocketFactory") and
    not initSslContext.getArgument(1) instanceof NullLiteral and
    DataFlow::localExprFlow(initSslContext.getQualifier(), getSocketFactory.getQualifier()) and
    DataFlow::localExprFlow(getSocketFactory, setSocketFactory.getArgument(0))
  )
}

/**
 * Holds if the given expression is an qualifier to a `URL.openConnection` or `URL.openStream` call
 * that is trusted due to its SSL socket factory being set.
 */
private predicate trustedUrlConnection(Expr url) {
  exists(MethodAccess openCon |
    openCon
        .getMethod()
        .getASourceOverriddenMethod*()
        .hasQualifiedName("java.net", "URL", "openConnection") and
    url = openCon.getQualifier() and
    exists(MethodAccess setSocketFactory |
      trustedSocketFactory(setSocketFactory, false) and
      TaintTracking::localExprTaint(openCon, setSocketFactory.getQualifier())
    )
  )
  or
  trustedSocketFactory(_, true) and
  exists(MethodAccess open |
    open.getMethod()
        .getASourceOverriddenMethod*()
        .hasQualifiedName("java.net", "URL", ["openConnection", "openStream"]) and
    url = open.getQualifier()
  )
}

private class MissingPinningSink extends DataFlow::Node {
  MissingPinningSink() {
    this instanceof UrlOpenSink and
    not trustedUrlConnection(this.asExpr())
  }
}

/** Configuration for finding uses of non trusted URLs. */
private class UntrustedUrlConfig extends TaintTracking::Configuration {
  UntrustedUrlConfig() { this = "UntrustedUrlConfig" }

  override predicate isSource(DataFlow::Node node) {
    exists(string d | trustedDomain(d)) and
    exists(string lit | lit = node.asExpr().(CompileTimeConstantExpr).getStringValue() |
      lit.matches("%://%") and // it's a URL
      not exists(string dom | trustedDomain(dom) and lit.matches("%" + dom + "%"))
    )
  }

  override predicate isSink(DataFlow::Node node) { node instanceof MissingPinningSink }
}

/** Holds if `node` is a network communication call for which certificate pinning is not implemented. */
predicate missingPinning(DataFlow::Node node) {
  isAndroid() and
  node instanceof MissingPinningSink and
  (
    not exists(string s | trustedDomain(s))
    or
    exists(UntrustedUrlConfig conf | conf.hasFlow(_, node))
  )
}
