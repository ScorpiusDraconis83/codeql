private import ruby
private import codeql.ruby.Concepts
private import codeql.ruby.ApiGraphs

/**
 * A call that makes an HTTP request using `Typhoeus`.
 * ```ruby
 * Typhoeus.get("http://example.com").body
 * ```
 */
class TyphoeusHttpRequest extends HTTP::Client::Request::Range {
  DataFlow::Node requestUse;
  API::Node requestNode;

  TyphoeusHttpRequest() {
    requestUse = requestNode.getAnImmediateUse() and
    requestNode =
      API::getTopLevelMember("Typhoeus")
          .getReturn(["get", "head", "delete", "options", "post", "put", "patch"]) and
    this = requestUse.asExpr().getExpr()
  }

  override DataFlow::Node getResponseBody() { result = requestNode.getAMethodCall("body") }

  override predicate disablesCertificateValidation(DataFlow::Node disablingNode) {
    // Check for `ssl_verifypeer: false` in the options hash.
    exists(DataFlow::Node arg, int i |
      i > 0 and arg.asExpr().getExpr() = requestUse.asExpr().getExpr().(MethodCall).getArgument(i)
    |
      // Either passed as an individual key:value argument, e.g.:
      // Typhoeus.get(..., ssl_verifypeer: false)
      isSslVerifyPeerFalsePair(arg.asExpr().getExpr()) and
      disablingNode = arg
      or
      // Or as a single hash argument, e.g.:
      // Typhoeus.get(..., { ssl_verifypeer: false, ... })
      exists(DataFlow::LocalSourceNode optionsNode, Pair p |
        p = optionsNode.asExpr().getExpr().(HashLiteral).getAKeyValuePair() and
        isSslVerifyPeerFalsePair(p) and
        optionsNode.flowsTo(arg) and
        disablingNode.asExpr().getExpr() = p
      )
    )
  }

  override string getFramework() { result = "Typhoeus" }
}

// Holds if `p` is the pair `ssl_verifypeer: false`.
private predicate isSslVerifyPeerFalsePair(Pair p) {
  p.getKey().(SymbolLiteral).getValueText() = "ssl_verifypeer" and
  exists(DataFlow::LocalSourceNode literal, DataFlow::Node value |
    (
      literal.asExpr().getExpr().(BooleanLiteral).isFalse() or
      literal.asExpr().getExpr().(IntegerLiteral).getValue() = 0
    ) and
    literal.flowsTo(value) and
    value.asExpr().getExpr() = p.getValue()
  )
}
