/**
 * Provides default sources, sinks and sanitizers for detecting
 * LDAP Injections, as well as extension points for adding your own
 */

private import codeql.ruby.Concepts
private import codeql.ruby.DataFlow
private import codeql.ruby.dataflow.BarrierGuards
private import codeql.ruby.dataflow.RemoteFlowSources
private import codeql.ruby.ApiGraphs

/**
 * Provides default sources, sinks and sanitizers for detecting
 * LDAP Injections, as well as extension points for adding your own
 */
module LdapInjection {
  /** A data flow source for LDAP Injection vulnerabilities */
  abstract class Source extends DataFlow::Node { }

  /** A data flow sink for LDAP Injection vulnerabilities */
  abstract class Sink extends DataFlow::Node { }

  /** A sanitizer for LDAP Injection vulnerabilities. */
  abstract class Sanitizer extends DataFlow::Node { }

  /**
   * Additional taint steps for "LDAP Injection" vulnerabilities.
   */
  predicate isAdditionalTaintStep(DataFlow::Node nodeFrom, DataFlow::Node nodeTo) {
    filterTaintStep(nodeFrom, nodeTo)
  }

  private predicate filterTaintStep(DataFlow::Node n1, DataFlow::Node n2) {
    exists(DataFlow::CallNode filterCall |
      (
        filterCall =
          API::getTopLevelMember("Net").getMember("LDAP").getMember("Filter").getAMethodCall(["eq"]) or
        filterCall.getMethodName() = ["[]"]
      ) and
      n1 = filterCall.getArgument([0, 1]) and
      n2 = filterCall
    )
  }

  /**
   * A source of remote user input, considered as a flow source.
   */
  private class RemoteFlowSourceAsSource extends Source, RemoteFlowSource { }

  /**
   * An LDAP query execution considered as a flow sink.
   */
  private class LdapExecutionAsSink extends Sink {
    LdapExecutionAsSink() { this = any(LdapExecution l).getQuery() }
  }

  /**
   * A comparison with a constant string, considered as a sanitizer-guard.
   */
  private class StringConstCompareAsSanitizerGuard extends Sanitizer, StringConstCompareBarrier { }

  /**
   * An inclusion check against an array of constant strings, considered as a
   * sanitizer-guard.
   */
  private class StringConstArrayInclusionCallAsSanitizer extends Sanitizer,
    StringConstArrayInclusionCallBarrier { }
}
