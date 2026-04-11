#include "spatial_preview/Json.hpp"

#include <cctype>
#include <fstream>
#include <iterator>
#include <sstream>

namespace spatial_preview {

JsonError::JsonError(const std::string& message) : std::runtime_error(message) {}

JsonValue::JsonValue() : storage_(nullptr) {}
JsonValue::JsonValue(std::nullptr_t value) : storage_(value) {}
JsonValue::JsonValue(bool value) : storage_(value) {}
JsonValue::JsonValue(double value) : storage_(value) {}
JsonValue::JsonValue(std::string value) : storage_(std::move(value)) {}
JsonValue::JsonValue(Array value) : storage_(std::move(value)) {}
JsonValue::JsonValue(Object value) : storage_(std::move(value)) {}

bool JsonValue::is_null() const { return std::holds_alternative<std::nullptr_t>(storage_); }
bool JsonValue::is_bool() const { return std::holds_alternative<bool>(storage_); }
bool JsonValue::is_number() const { return std::holds_alternative<double>(storage_); }
bool JsonValue::is_string() const { return std::holds_alternative<std::string>(storage_); }
bool JsonValue::is_array() const { return std::holds_alternative<Array>(storage_); }
bool JsonValue::is_object() const { return std::holds_alternative<Object>(storage_); }

bool JsonValue::as_bool() const { return std::get<bool>(storage_); }
double JsonValue::as_number() const { return std::get<double>(storage_); }
const std::string& JsonValue::as_string() const { return std::get<std::string>(storage_); }
const JsonValue::Array& JsonValue::as_array() const { return std::get<Array>(storage_); }
const JsonValue::Object& JsonValue::as_object() const { return std::get<Object>(storage_); }

bool JsonValue::contains(const std::string& key) const {
  if (!is_object()) {
    return false;
  }
  return as_object().contains(key);
}

const JsonValue& JsonValue::at(const std::string& key) const {
  if (!is_object()) {
    throw JsonError("value is not an object");
  }
  const auto& object = as_object();
  const auto iter = object.find(key);
  if (iter == object.end()) {
    throw JsonError("missing key: " + key);
  }
  return iter->second;
}

namespace {

class Parser {
 public:
  explicit Parser(const std::string& text) : text_(text) {}

  JsonValue parse() {
    skip_whitespace();
    JsonValue result = parse_value();
    skip_whitespace();
    if (!is_end()) {
      fail("unexpected trailing characters");
    }
    return result;
  }

 private:
  JsonValue parse_value() {
    if (is_end()) {
      fail("unexpected end of input");
    }

    const char c = peek();
    if (c == '{') {
      return parse_object();
    }
    if (c == '[') {
      return parse_array();
    }
    if (c == '"') {
      return JsonValue(parse_string());
    }
    if (c == 't') {
      consume_literal("true");
      return JsonValue(true);
    }
    if (c == 'f') {
      consume_literal("false");
      return JsonValue(false);
    }
    if (c == 'n') {
      consume_literal("null");
      return JsonValue(nullptr);
    }
    if (c == '-' || std::isdigit(static_cast<unsigned char>(c))) {
      return JsonValue(parse_number());
    }
    fail("unexpected token");
    return JsonValue();
  }

  JsonValue parse_object() {
    expect('{');
    JsonValue::Object object;
    skip_whitespace();
    if (try_consume('}')) {
      return JsonValue(std::move(object));
    }

    while (true) {
      skip_whitespace();
      if (peek() != '"') {
        fail("expected string key");
      }
      std::string key = parse_string();
      skip_whitespace();
      expect(':');
      skip_whitespace();
      object.emplace(std::move(key), parse_value());
      skip_whitespace();
      if (try_consume('}')) {
        break;
      }
      expect(',');
      skip_whitespace();
    }
    return JsonValue(std::move(object));
  }

  JsonValue parse_array() {
    expect('[');
    JsonValue::Array array;
    skip_whitespace();
    if (try_consume(']')) {
      return JsonValue(std::move(array));
    }

    while (true) {
      skip_whitespace();
      array.push_back(parse_value());
      skip_whitespace();
      if (try_consume(']')) {
        break;
      }
      expect(',');
      skip_whitespace();
    }
    return JsonValue(std::move(array));
  }

  std::string parse_string() {
    expect('"');
    std::string result;
    while (!is_end()) {
      char c = get();
      if (c == '"') {
        return result;
      }
      if (c == '\\') {
        if (is_end()) {
          fail("incomplete escape sequence");
        }
        const char escaped = get();
        switch (escaped) {
          case '"':
          case '\\':
          case '/':
            result.push_back(escaped);
            break;
          case 'b':
            result.push_back('\b');
            break;
          case 'f':
            result.push_back('\f');
            break;
          case 'n':
            result.push_back('\n');
            break;
          case 'r':
            result.push_back('\r');
            break;
          case 't':
            result.push_back('\t');
            break;
          default:
            fail("unsupported escape sequence");
        }
      } else {
        result.push_back(c);
      }
    }
    fail("unterminated string");
    return {};
  }

  double parse_number() {
    const std::size_t start = index_;
    if (peek() == '-') {
      ++index_;
    }

    consume_digits();

    if (!is_end() && peek() == '.') {
      ++index_;
      consume_digits();
    }

    if (!is_end() && (peek() == 'e' || peek() == 'E')) {
      ++index_;
      if (!is_end() && (peek() == '+' || peek() == '-')) {
        ++index_;
      }
      consume_digits();
    }

    return std::stod(text_.substr(start, index_ - start));
  }

  void consume_digits() {
    if (is_end() || !std::isdigit(static_cast<unsigned char>(peek()))) {
      fail("expected digit");
    }
    while (!is_end() && std::isdigit(static_cast<unsigned char>(peek()))) {
      ++index_;
    }
  }

  void consume_literal(const char* literal) {
    while (*literal != '\0') {
      if (is_end() || get() != *literal) {
        fail("invalid literal");
      }
      ++literal;
    }
  }

  void skip_whitespace() {
    while (!is_end() && std::isspace(static_cast<unsigned char>(peek()))) {
      ++index_;
    }
  }

  void expect(char expected) {
    if (is_end() || get() != expected) {
      std::ostringstream message;
      message << "expected '" << expected << "'";
      fail(message.str());
    }
  }

  bool try_consume(char expected) {
    if (!is_end() && peek() == expected) {
      ++index_;
      return true;
    }
    return false;
  }

  char peek() const { return text_[index_]; }
  char get() { return text_[index_++]; }
  bool is_end() const { return index_ >= text_.size(); }

  [[noreturn]] void fail(const std::string& message) const {
    std::ostringstream stream;
    stream << "JSON parse error at byte " << index_ << ": " << message;
    throw JsonError(stream.str());
  }

  const std::string& text_;
  std::size_t index_ = 0;
};

}  // namespace

JsonValue parse_json(const std::string& text) {
  return Parser(text).parse();
}

JsonValue parse_json_file(const std::string& path) {
  std::ifstream file(path, std::ios::binary);
  if (!file) {
    throw JsonError("failed to open JSON file: " + path);
  }

  std::string contents((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
  return parse_json(contents);
}

}  // namespace spatial_preview
