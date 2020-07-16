/**
 * @name Use of constant `state` value in Oauth2 URL.
 * @description Using a constant value for the `state` in the oauth2 URL makes the application
 *              susceptible to CSRF attacks.
 * @kind path-problem
 * @problem.severity error
 * @id go/constant-oauth2-state
 * @tags security
 *       external/cwe/cwe-352
 */

import go
import DataFlow::PathGraph

/*
 * A method that creates a new URL that will send the user
 * to the oauth2 authorization dialog of the provider.
 */

class AuthCodeURL extends Method {
  AuthCodeURL() { this.hasQualifiedName("golang.org/x/oauth2", "Config", "AuthCodeURL") }
}

/*
 * A flow of a constant string value to a call to AuthCodeURL as the
 * `state` parameter.
 */

class ConstantStateFlowConf extends TaintTracking::Configuration {
  ConstantStateFlowConf() { this = "ConstantStateFlowConf" }

  predicate isSource(DataFlow::Node source, Literal state) {
    state.isConst() and source.asExpr() = state
  }

  predicate isSink(DataFlow::Node sink, DataFlow::CallNode call) {
    exists(AuthCodeURL m | call = m.getACall() | sink = call.getArgument(0))
  }

  override predicate isSource(DataFlow::Node source) { isSource(source, _) }

  override predicate isSink(DataFlow::Node sink) { isSink(sink, _) }
}

from ConstantStateFlowConf cfg, DataFlow::PathNode source, DataFlow::PathNode sink
where cfg.hasFlowPath(source, sink)
select sink.getNode(), source, sink, "Using a constant $@ to create oauth2 URLs.", source.getNode(),
  "state string"
