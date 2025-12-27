# JsonPath module for accessing nested data structures using dot notation and array indexing.
#
# This is a lightweight JSONPath implementation that provides simple navigation through
# nested hashes and arrays using a dot-separated path syntax.
#
# Supported Path Syntax:
#   - "key"                          - Access a hash key
#   - "key.nested"                   - Access nested hash keys
#   - "key[0]"                       - Access a hash key, then the first element of an array
#   - "[0]"                          - Access the first element of an array
#   - "key.nested[2].property"       - Combine hash navigation and array indexing
#   - "component[0].valueQuantity.value" - Complex nested navigation
#
# Examples:
#   data = {
#     "name" => [{ "given" => ["John"], "family" => "Doe" }],
#     "code" => { "text" => "Sample", "coding" => [{ "system" => "http://...", "code" => "123" }] }
#   }
#
#   JsonPath.get(data, "name[0].given[0]")              # => "John"
#   JsonPath.get(data, "code.text")                     # => "Sample"
#   JsonPath.get(data, "code.coding[0].system")         # => "http://..."
#   JsonPath.get(data, "name[0].family")                # => "Doe"
#   JsonPath.get(data, "missing.path")                  # => nil
#
# Behavior:
#   - Returns nil if the path is invalid or if any intermediate value is nil
#   - Supports both string and symbol keys for hash access
#   - Array indices must be non-negative integers
#   - Empty or nil paths return nil
#   - Non-existent keys or out-of-bounds indices return nil
#
# Limitations:
#   - Does not support wildcard selections (e.g., "items[*].name")
#   - Does not support filter expressions (e.g., "items[?(@.price < 10)]")
#   - Does not support recursive descent (e.g., "..name")
#   - Array indices must be explicit integers, not ranges
#   - Only supports forward navigation (no parent/sibling access)
module JsonPath
  # Regex for matching array index notation with a key (e.g., "key[0]")
  ARRAY_INDEX_REGEX = /\A(.+?)\[(\d+)\]\z/

  # Regex for matching standalone array index notation (e.g., "[0]")
  INDEX_ONLY_REGEX = /\A\[(\d+)\]\z/

  # Retrieves a value from a nested object using a dot-separated path.
  #
  # @param obj [Hash, Array] The object to navigate
  # @param path [String] The dot-separated path (e.g., "key.nested[0].value")
  # @return [Object, nil] The value at the specified path, or nil if not found
  def self.get(obj, path)
    return if obj.nil? || path.to_s.strip.empty?

    tokens = path.split(".")

    tokens.reduce(obj) do |current, token|
      return if current.nil?

      key, idx = parse_token(token)

      # 1) optional hash access
      if key.present?
        return unless current.is_a?(Hash)
        current = current[key] || current[key.to_sym]
      end

      # 2) optional array access
      if !idx.nil?
        return unless current.is_a?(Array)
        current = current[idx]
      end

      current
    end
  end

  # Parses a single path token to extract the key and optional array index.
  #
  # @param token [String] A single token from the path (e.g., "key[0]", "[0]", or "key")
  # @return [Array<String, Integer|nil>] A tuple of [key, index] where index is nil if not present
  #
  # @example
  #   parse_token("key[0]")  # => ["key", 0]
  #   parse_token("[5]")     # => ["", 5]
  #   parse_token("key")     # => ["key", nil]
  def self.parse_token(token)
    if (m = token.match(ARRAY_INDEX_REGEX))
      [ m[1], m[2].to_i ]
    elsif (m = token.match(INDEX_ONLY_REGEX))
      [ "", m[1].to_i ]
    else
      [ token, nil ]
    end
  end
end
