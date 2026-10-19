// stage/glsl_comp — 프로젝터 출력 합성 (이 결과가 null_projector = 실제 프로젝터로 나가는 그림)
// 입력 0: render_projector (콘텐츠), 1: null_trail (파티클 잔상), 2: renderselect_pdist (g = 큐브 마스크)
//
// 레퍼런스(숲길 위 깨진 프레임)처럼 프로젝터 화면 단위로 글리치를 건다.
//   가로 띠 밀림: 어택(hit)에서 몇몇 띠가 옆으로 밀린다
//   모자이크 블록: 블록이 한 색으로 뭉개지거나 옆 블록을 끌어온다 (데이터모시). 일부는 청록으로 물든다
// 마지막에 큐브 마스크를 곱해 큐브 밖으로는 빛이 나가지 않게 한다.

uniform vec4 uGlitch;  // x 글리치 세기, y 블록 밀도, z 잔상 세기, w time
uniform vec4 uHitsG;   // x kick, y hit, z energy, w high

layout(location = 0) out vec4 fragColor;

const vec3 C_TURQ = vec3(0.100, 0.780, 0.800);
const vec3 C_AQUA = vec3(0.700, 0.920, 0.870);

float Hash(vec2 p)
{
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main()
{
	vec2 uv = vUV.st;
	float t = uGlitch.w;
	float g = uGlitch.x * (0.2 + 0.8 * smoothstep(0.35, 1.0, uHitsG.y)) * (0.5 + 0.5 * uHitsG.z);

	// 가로 띠 밀림
	float band = floor(uv.y * 54.0);
	float bt = floor(t * 9.0);
	float bandOn = step(1.0 - 0.4 * g, Hash(vec2(band, bt)));
	vec2 suv = uv;
	suv.x += (Hash(vec2(band, bt + 7.0)) - 0.5) * 0.07 * bandOn * g;

	// 모자이크 블록 (가로로 긴 블록이 레퍼런스와 비슷하다)
	vec2 grid = vec2(36.0, 30.0);
	vec2 cell = floor(suv * grid);
	float ct = floor(t * 5.0 + Hash(cell) * 4.0);
	float cellOn = step(1.0 - (0.015 + 0.22 * g) * uGlitch.y, Hash(cell + vec2(ct * 0.37, ct * 0.11)));
	vec2 drag = vec2(floor((Hash(cell + ct) - 0.5) * 5.0), 0.0) / grid;
	vec3 base = texture(sTD2DInputs[0], suv).rgb;
	vec3 block = texture(sTD2DInputs[0], (cell + 0.5) / grid + drag).rgb;
	float tint = step(0.7, Hash(cell * 1.7 + ct));
	block = mix(block, mix(C_TURQ, C_AQUA, Hash(cell + 3.0)) * (0.4 + 0.6 * dot(block, vec3(0.33)) * 2.0), tint * 0.75);
	vec3 col = mix(base, block, cellOn);

	// 잔상
	col += texture(sTD2DInputs[1], uv).rgb * uGlitch.z;

	// 큐브 밖은 검정
	float mask = clamp(texture(sTD2DInputs[2], uv).g, 0.0, 1.0);
	fragColor = TDOutputSwizzle(vec4(col * mask, 1.0));
}
