#pragma once

#include <iomanip>
#include <sstream>
#include <string>

namespace spatial_preview {

struct Vec3 {
  double x = 0.0;
  double y = 0.0;
  double z = 0.0;
};

struct Transform {
  Vec3 position;
  Vec3 rotation_euler_deg;
};

inline Vec3 lerp(const Vec3& a, const Vec3& b, double alpha) {
  return {
      a.x + (b.x - a.x) * alpha,
      a.y + (b.y - a.y) * alpha,
      a.z + (b.z - a.z) * alpha,
  };
}

inline Vec3 operator+(const Vec3& a, const Vec3& b) {
  return {a.x + b.x, a.y + b.y, a.z + b.z};
}

inline Vec3 operator-(const Vec3& a, const Vec3& b) {
  return {a.x - b.x, a.y - b.y, a.z - b.z};
}

inline Vec3 operator*(const Vec3& value, double scalar) {
  return {value.x * scalar, value.y * scalar, value.z * scalar};
}

inline std::string to_string(const Vec3& value) {
  std::ostringstream stream;
  stream << std::fixed << std::setprecision(3)
         << "[" << value.x << ", " << value.y << ", " << value.z << "]";
  return stream.str();
}

}  // namespace spatial_preview
