// stage/glsl_present — 발표 화면 구성
// 입력 0: null_previs (합주실 미리보기), 1: null_projector (프로젝터로 나가는 그림)
// uView.x: 0 = 미리보기, 1 = 프로젝터 출력, 2 = 미리보기 + 오른쪽 아래 작은 프로젝터 화면

uniform vec4 uView;

layout(location = 0) out vec4 fragColor;

void main()
{
	vec2 uv = vUV.st;
	int mode = int(uView.x + 0.5);
	vec3 col;
	if (mode == 1) {
		col = texture(sTD2DInputs[1], uv).rgb;
	} else {
		col = texture(sTD2DInputs[0], uv).rgb;
		if (mode == 2) {
			vec2 lo = vec2(0.70, 0.04);
			vec2 hi = vec2(0.97, 0.04 + 0.27);
			if (all(greaterThanEqual(uv, lo)) && all(lessThanEqual(uv, hi))) {
				vec2 iuv = (uv - lo) / (hi - lo);
				vec2 px = uTDOutputInfo.res.xy / (hi - lo);
				bool border = any(lessThan(iuv, px * 1.5)) || any(greaterThan(iuv, 1.0 - px * 1.5));
				col = border ? vec3(0.70, 0.92, 0.87) * 0.8 : texture(sTD2DInputs[1], iuv).rgb;
			}
		}
	}
	fragColor = TDOutputSwizzle(vec4(clamp(col, 0.0, 1.0), 1.0));
}
