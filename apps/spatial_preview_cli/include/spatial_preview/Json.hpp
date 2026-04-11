#pragma once

#include <cstddef>
#include <map>
#include <stdexcept>
#include <string>
#include <variant>
#include <vector>

namespace spatial_preview {

class JsonError : public std::runtime_error {
 public:
  explicit JsonError(const std::string& message);
};

class JsonValue {
 public:
  using Object = std::map<std::string, JsonValue>;
  using Array = std::vector<JsonValue>;
  using Storage = std::variant<std::nullptr_t, bool, double, std::string, Array, Object>;

  JsonValue();
  explicit JsonValue(std::nullptr_t value);
  explicit JsonValue(bool value);
  explicit JsonValue(double value);
  explicit JsonValue(std::string value);
  explicit JsonValue(Array value);
  explicit JsonValue(Object value);

  bool is_null() const;
  bool is_bool() const;
  bool is_number() const;
  bool is_string() const;
  bool is_array() const;
  bool is_object() const;

  bool as_bool() const;
  double as_number() const;
  const std::string& as_string() const;
  const Array& as_array() const;
  const Object& as_object() const;

  bool contains(const std::string& key) const;
  const JsonValue& at(const std::string& key) const;

 private:
  Storage storage_;
};

JsonValue parse_json(const std::string& text);
JsonValue parse_json_file(const std::string& path);

}  // namespace spatial_preview
