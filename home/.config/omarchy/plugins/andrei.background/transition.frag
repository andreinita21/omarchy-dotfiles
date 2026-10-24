#version 440
// Every desktop transition in one pass: the old and new wallpapers are
// sampled directly and the reveal shape is computed per pixel, so a frame
// costs one full-screen draw instead of re-tessellated shapes rendered into
// offscreen layers. Rebuild after editing:
//   qsb --glsl "100es,120,150,300es" --hlsl 50 --msl 12 -o transition.frag.qsb transition.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  float progress;
  float effect;
  float seed;
  vec2 res;        // physical pixels
  vec2 fromScale;  // PreserveAspectCrop for each texture
  vec2 toScale;
};

layout(binding = 1) uniform sampler2D fromTex;
layout(binding = 2) uniform sampler2D toTex;

const float SLANT = -0.18;
const float TAU = 6.28318530718;

// Effect ids, matching root.effects in Background.qml.
const int FADE = 0;
const int BLINDS = 1;
const int WIPE = 2;
const int CIRCLE = 3;
const int CLOCK = 4;
const int SLIDE = 5;
const int ZOOM = 6;
const int TILES = 7;
const int BARS = 8;

vec4 sampleCrop(sampler2D tex, vec2 uv, vec2 scale) {
  return texture(tex, vec2(0.5) + (uv - vec2(0.5)) * scale);
}

float hash(float i) {
  return fract(sin(i * 12.9898 + seed * 78.233) * 43758.5453);
}

// Signed distance in pixels to the edge of the revealed area, turned into
// one pixel of anti-aliased coverage.
float edge(float d) {
  return clamp(d + 0.5, 0.0, 1.0);
}

float coverage(int fx, vec2 px, float p) {
  if (p <= 0.0) return 0.0;
  if (p >= 1.0) return 1.0;
  float w = res.x;
  float h = res.y;

  if (fx == BLINDS) {
    // Slanted slats that each widen from their own centre line.
    float slice = w / 6.0;
    float local = px.x - SLANT * (px.y - h * 0.5) + abs(SLANT) * h * 0.5;
    float m = mod(local, slice) - slice * 0.5;
    return edge((slice * 0.5 + 2.0) * p - abs(m));
  }
  if (fx == WIPE) {
    // One slanted band opening from the centre.
    float center = w * 0.5 + SLANT * (px.y - h * 0.5);
    float reach = w * 0.5 + abs(SLANT) * h * 0.5 + 4.0;
    return edge(reach * p - abs(px.x - center));
  }
  if (fx == CIRCLE) {
    float r = (length(res) + 8.0) * 0.5 * p;
    return edge(r - length(px - res * 0.5));
  }
  if (fx == CLOCK) {
    // Radial sweep from twelve o'clock, clockwise.
    vec2 d = px - res * 0.5;
    float a = atan(d.x, -d.y);
    if (a < 0.0) a += TAU;
    return edge((p * TAU - a) * max(length(d), 1.0));
  }
  if (fx == TILES) {
    // A 16-wide grid of squares popping in at random.
    float size = w / 16.0;
    vec2 cell = floor(px / size);
    float s = clamp((p - hash(cell.y * 16.0 + cell.x) * 0.6) / 0.4, 0.0, 1.0);
    if (s <= 0.0) return 0.0;
    vec2 local = abs(px - (cell + 0.5) * size);
    return edge(size * 0.5 * s + 0.5 - max(local.x, local.y));
  }
  if (fx == BARS) {
    // Strips dropping in left to right, alternating top and bottom.
    float barWidth = w / 12.0;
    float i = floor(px.x / barWidth);
    float f = clamp((p - i / 12.0 * 0.5) / 0.5, 0.0, 1.0);
    if (f <= 0.0) return 0.0;
    float d = mod(i, 2.0) < 0.5 ? h * f - px.y : px.y - h * (1.0 - f);
    return edge(d);
  }
  return p;
}

void main() {
  vec2 uv = qt_TexCoord0;
  vec2 px = uv * res;
  float p = progress;
  int fx = int(effect + 0.5);
  vec4 color;

  if (fx == SLIDE) {
    // The new wallpaper slides in from the right, pushing the old one left.
    float front = res.x * (1.0 - p);
    if (px.x >= front)
      color = sampleCrop(toTex, vec2((px.x - front) / res.x, uv.y), toScale);
    else
      color = sampleCrop(fromTex, vec2((px.x + res.x * 0.35 * p) / res.x, uv.y), fromScale);
  } else if (fx == ZOOM) {
    // Fade in while settling from a slight zoom.
    float s = 1.12 - 0.12 * p;
    vec4 to = sampleCrop(toTex, vec2(0.5) + (uv - vec2(0.5)) / s, toScale);
    color = mix(sampleCrop(fromTex, uv, fromScale), to, p);
  } else {
    color = mix(sampleCrop(fromTex, uv, fromScale), sampleCrop(toTex, uv, toScale), coverage(fx, px, p));
  }

  fragColor = color * qt_Opacity;
}
