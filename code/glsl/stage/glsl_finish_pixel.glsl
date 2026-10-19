// stage/glsl_finish — 최종 색 정리
// 색수차(어택 때 조금 더) → 노출 → ACES 톤매핑 → 어두운 곳을 깊은 초록으로 → 비네팅 → 필름 그레인
// 입력 0: bloom_glow (HDR)

uniform vec4 uFinish;  // x 노출, y 비네팅, z 그레인, w 색수차
uniform vec4 uFx;      // x time, y hit

layout(location = 0) out vec4 fragColor;

vec3 Aces(vec3 x)
{
	const float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
	return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main()
{
	vec2 uv = vUV.st;
	vec2 c = uv - 0.5;
	float ca = uFinish.w * (0.6 + 1.6 * uFx.y) * dot(c, c);
	vec3 col;
	col.r = texture(sTD2DInputs[0], uv + c * ca).r;
	col.g = texture(sTD2DInputs[0], uv).g;
	col.b = texture(sTD2DInputs[0], uv - c * ca).b;

	col = Aces(col * uFinish.x);
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col += vec3(0.0, 0.010, 0.007) * (1.0 - smoothstep(0.0, 0.2, luma));

	float vig = smoothstep(1.05, 0.3, length(c * vec2(1.0, 0.85)) * 1.3);
	col *= mix(1.0, vig, uFinish.y);

	vec2 seedUv = uv * uTDOutputInfo.res.zw + fract(uFx.x * 7.13) * vec2(17.3, 91.1);
	float n = fract(sin(dot(seedUv, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * uFinish.z;

	fragColor = TDOutputSwizzle(vec4(clamp(col, 0.0, 1.0), 1.0));
}
