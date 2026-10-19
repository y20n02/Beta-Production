// stage/glsl_particle — 공통 파티클 픽셀 셰이더 (render_projector에서 그림)
// 빛 입자는 부드러운 원형 빛, 잎은 끝이 뾰족한 타원 + 가운데 잎맥.
// 더하기 블렌딩이라 알파는 0으로 둔다. 색 버퍼 1번(잔상용)에도 같은 색을 쓰고,
// 2번(거리·마스크)에는 0을 더해 큐브 거리 정보를 건드리지 않는다.

in Vert {
	vec4 color;
	vec2 uv;
	flat float kind;
	flat int cameraIndex;
} iVert;

layout(location = 0) out vec4 oFragColor[TD_NUM_COLOR_BUFFERS];

void main()
{
	TDCheckDiscard();
	vec2 q = iVert.uv;  // -0.5 ~ 0.5
	float a;
	if (iVert.kind > 0.5) {
		vec2 l = vec2(q.x * 2.4, q.y);
		float body = smoothstep(0.5, 0.36, length(l) + abs(q.y) * 0.35);
		float vein = smoothstep(0.035, 0.0, abs(q.x)) * smoothstep(0.45, 0.0, abs(q.y));
		a = body * (0.75 + 0.5 * vein);
	} else {
		float r = length(q) * 2.0;
		a = exp(-r * r * 7.0) + smoothstep(0.22, 0.0, r) * 0.8;
	}
	vec3 c = iVert.color.rgb * a * iVert.color.a;
	if (dot(c, c) < 1e-8) {
		discard;
	}
	oFragColor[0] = TDOutputSwizzle(vec4(c, 0.0));
#if TD_NUM_COLOR_BUFFERS > 1
	oFragColor[1] = TDOutputSwizzle(vec4(c, 0.0));
#endif
#if TD_NUM_COLOR_BUFFERS > 2
	oFragColor[2] = vec4(0.0);
#endif
}
