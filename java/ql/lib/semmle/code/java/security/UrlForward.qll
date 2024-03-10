/** Provides classes to reason about URL forward attacks. */

import java
private import semmle.code.java.dataflow.ExternalFlow
private import semmle.code.java.dataflow.FlowSources
private import semmle.code.java.dataflow.StringPrefixes
private import semmle.code.java.security.PathSanitizer
private import semmle.code.java.controlflow.Guards
private import semmle.code.java.security.Sanitizers

/** A URL forward sink. */
abstract class UrlForwardSink extends DataFlow::Node { }

/**
 * A default sink representing methods susceptible to URL
 * forwarding attacks.
 */
private class DefaultUrlForwardSink extends UrlForwardSink {
  DefaultUrlForwardSink() { sinkNode(this, "url-forward") }
}

/**
 * An expression appended (perhaps indirectly) to `"forward:"`
 * and reachable from a Spring entry point.
 */
private class SpringUrlForwardSink extends UrlForwardSink {
  SpringUrlForwardSink() {
    any(SpringRequestMappingMethod srmm).polyCalls*(this.getEnclosingCallable()) and
    this.asExpr() = any(ForwardPrefix fp).getAnAppendedExpression()
  }
}

private class ForwardPrefix extends InterestingPrefix {
  ForwardPrefix() { this.getStringValue() = "forward:" }

  override int getOffset() { result = 0 }
}

/** A URL forward barrier. */
abstract class UrlForwardBarrier extends DataFlow::Node { }

private class PrimitiveBarrier extends UrlForwardBarrier instanceof SimpleTypeSanitizer { }

// TODO: QLDoc
private class FollowsBarrierPrefix extends UrlForwardBarrier {
  FollowsBarrierPrefix() { this.asExpr() = any(BarrierPrefix fp).getAnAppendedExpression() }
}

// TODO: QLDoc and fix broadness of this prefix check...
private class BarrierPrefix extends InterestingPrefix {
  BarrierPrefix() {
    not this.getStringValue().matches("/WEB-INF/%") and
    not this instanceof ForwardPrefix
  }

  override int getOffset() { result = 0 }
}

/** A barrier that protects against path injection vulnerabilities while accounting for URL encoding. */
private class UrlPathBarrier extends UrlForwardBarrier instanceof PathInjectionSanitizer {
  UrlPathBarrier() {
    this instanceof ExactPathMatchSanitizer
    or
    this instanceof NoUrlEncodingBarrier
    or
    this instanceof FullyDecodesUrlBarrier
  }
}

/** A call to a method that decodes a URL. */
abstract class UrlDecodeCall extends MethodCall { }

private class DefaultUrlDecodeCall extends UrlDecodeCall {
  DefaultUrlDecodeCall() {
    this.getMethod() instanceof UrlDecodeMethod or
    this.getMethod().hasQualifiedName("org.eclipse.jetty.util.URIUtil", "URIUtil", "decodePath")
  }
}

/** A repeated call to a method that decodes a URL. */
abstract class RepeatedUrlDecodeCall extends MethodCall { }

private class DefaultRepeatedUrlDecodeCall extends RepeatedUrlDecodeCall instanceof UrlDecodeCall {
  DefaultRepeatedUrlDecodeCall() { this.getAnEnclosingStmt() instanceof LoopStmt }
}

/** A method call that checks a string for URL encoding. */
abstract class CheckUrlEncodingCall extends MethodCall { }

private class DefaultCheckUrlEncodingCall extends CheckUrlEncodingCall {
  DefaultCheckUrlEncodingCall() {
    this.getMethod() instanceof StringContainsMethod and
    this.getArgument(0).(CompileTimeConstantExpr).getStringValue() = "%"
  }
}

/** A guard that looks for a method call that checks for URL encoding. */
private class CheckUrlEncodingGuard extends Guard instanceof CheckUrlEncodingCall {
  Expr getCheckedExpr() { result = this.(MethodCall).getQualifier() }
}

/** Holds if `g` is guard for a URL that does not contain URL encoding. */
private predicate noUrlEncodingGuard(Guard g, Expr e, boolean branch) {
  g instanceof CheckUrlEncodingGuard and
  e = g.(CheckUrlEncodingGuard).getCheckedExpr() and
  branch = false
  or
  branch = false and
  g.(Expr).getType() instanceof BooleanType and
  (
    exists(CheckUrlEncodingCall call, AssignExpr ae |
      ae.getSource() = call and
      e = call.getQualifier() and
      g = ae.getDest()
    )
    or
    exists(CheckUrlEncodingCall call, LocalVariableDeclExpr vde |
      vde.getInitOrPatternSource() = call and
      e = call.getQualifier() and
      g = vde.getAnAccess()
    )
  )
}

/** A barrier for URLs that do not contain URL encoding. */
private class NoUrlEncodingBarrier extends DataFlow::Node {
  NoUrlEncodingBarrier() { this = DataFlow::BarrierGuard<noUrlEncodingGuard/3>::getABarrierNode() }
}

/** Holds if `g` is guard for a URL that is fully decoded. */
private predicate fullyDecodesUrlGuard(Expr e) {
  exists(CheckUrlEncodingGuard g, RepeatedUrlDecodeCall decodeCall |
    e = g.getCheckedExpr() and
    g.controls(decodeCall.getBasicBlock(), true)
  )
}

/** A barrier for URLs that are fully decoded. */
private class FullyDecodesUrlBarrier extends DataFlow::Node {
  FullyDecodesUrlBarrier() {
    exists(Variable v, Expr e | this.asExpr() = v.getAnAccess() |
      fullyDecodesUrlGuard(e) and
      e = v.getAnAccess() and
      e.getBasicBlock().bbDominates(this.asExpr().getBasicBlock())
    )
  }
}
