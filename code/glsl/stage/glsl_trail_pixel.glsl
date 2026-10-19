// stage/glsl_trail — 파티클 잔상
// 입력 0: 이번 프레임 파티클 (render_scene 색 버퍼 1, 큐브가 가린 부분은 검정)
// 입력 1: 지난 프레임 잔상 (feedback_trail)
// 지난 잔상을 살짝 위로 밀고 옆으로 번지게 한 뒤 줄여서, 떠오르는 빛 꼬리를 만든다.

uniform vec4 uTrail;  // x 남는 비율(0~1), y 위로 미는 양(uv/프레임), z 옆 번짐(px)

layout(location = 0) out vec4 fragColor;

void main()
{
	vec2 uv = vUV.st;
	vec2 px = uTD2DInfos[1].res.xy;
	vec2 fuv = uv - vec2(0.0, uTrail.y);
	vec2 side = vec2(px.x * uTrail.z, 0.0);
	vec3 fb = texture(sTD2DInputs[1], fuv).rgb * 0.5
		+ texture(sTD2DInputs[1], fuv + side).rgb * 0.25
		+ texture(sTD2DInputs[1], fuv - side).rgb * 0.25;
	vec3 cur = texture(sTD2DInputs[0], uv).rgb;
	vec3 col = max(cur, fb * uTrail.x);
	fragColor = TDOutputSwizzle(vec4(col, 1.0));
}
