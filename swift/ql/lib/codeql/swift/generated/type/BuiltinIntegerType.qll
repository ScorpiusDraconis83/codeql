// generated by codegen/codegen.py
/**
 * This module provides the generated definition of `BuiltinIntegerType`.
 * INTERNAL: Do not import directly.
 */

private import codeql.swift.generated.Synth
private import codeql.swift.generated.Raw
import codeql.swift.elements.type.AnyBuiltinIntegerType

module Generated {
  /**
   * INTERNAL: Do not reference the `Generated::BuiltinIntegerType` class directly.
   * Use the subclass `BuiltinIntegerType`, where the following predicates are available.
   */
  class BuiltinIntegerType extends Synth::TBuiltinIntegerType, AnyBuiltinIntegerType {
    override string getAPrimaryQlClass() { result = "BuiltinIntegerType" }

    /**
     * Gets the width of this builtin integer type, if it exists.
     */
    int getWidth() {
      result = Synth::convertBuiltinIntegerTypeToRaw(this).(Raw::BuiltinIntegerType).getWidth()
    }

    /**
     * Holds if `getWidth()` exists.
     */
    final predicate hasWidth() { exists(this.getWidth()) }
  }
}
