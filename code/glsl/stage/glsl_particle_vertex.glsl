// stage/glsl_particle — 공통 파티클 정점 셰이더 (Alpha의 꽃잎 파티클을 발전시킨 것)
// render_projector(프로젝터 시점)에서 그려지므로, 실제로는 큐브 면 위에 맺힌다.
//
// 시뮬레이션 없이 인스턴스 번호와 시간으로 위치를 계산한다 (매 테이크 같은 움직임).
// 각 입자는 수명마다 아무 큐브의 윗면·옆면에서 새로 태어나 소용돌이치며 떠오른다.
//   - 빛 입자(86%): 작고 둥근 빛. 고음에 반짝이고 킥에 밝아짐
//   - 잎(14%): 크고 길쭉한 잎 모양. 천천히 돌며 흩날림
// 곡이 조용하면(energy 낮음) 보이는 입자 수가 줄어든다. 킥이 오면 바깥으로 살짝 밀려난다.
// 사각형(rect_sprite, -0.5~0.5)을 카메라를 향하게 세워 그린다.

uniform vec4 uAudio;  // x level, y low, z mid, w high
uniform vec4 uHits;   // x kick, y hit, z energy
uniform vec4 uClock;  // x time
uniform vec4 uPart;   // x 크기 배율, y 상승 속도(m/s), z 퍼짐, w 큐브 개수
uniform samplerBuffer uCubes;  // 큐브마다 (tx, ty, tz, s)

out Vert {
	vec4 color;
	vec2 uv;
	flat float kind;
	flat int cameraIndex;
} oVert;

const vec3 C_TEAL = vec3(0.090, 0.520, 0.480);
const vec3 C_LEAF = vec3(0.420, 0.700, 0.330);
const vec3 C_AQUA = vec3(0.700, 0.920, 0.870);
const vec3 C_SUN = vec3(1.000, 0.920, 0.740);

float H(float n)
{
	return fract(sin(n) * 43758.5453123);
}

void main()
{
	float fid = float(TDInstanceID());
	float t = uClock.x;
	float r1 = H(fid * 1.17 + 0.3);
	float r2 = H(fid * 2.31 + 1.7);
	float r3 = H(fid * 3.73 + 2.9);
	float r4 = H(fid * 5.19 + 4.1);
	float kind = step(0.86, H(fid * 7.07 + 5.3));

	// 수명과 나이
	float life = mix(5.0, 11.0, r1) * mix(1.0, 1.4, kind);
	float tt = t / life + r2;
	float age = fract(tt);
	float cycle = floor(tt);

	// 태어나는 곳: 수명마다 다른 큐브의 윗면 또는 옆면
	int numCubes = max(int(uPart.w), 1);
	int ci = min(int(H(fid * 0.73 + cycle * 1.31) * float(numCubes)), numCubes - 1);
	vec4 cube = texelFetch(uCubes, ci);
	float halfS = cube.w * 0.5;
	vec2 fr = vec2(H(fid * 4.4 + cycle * 0.9), H(fid * 6.1 + cycle * 1.3)) * 2.0 - 1.0;
	float face = H(fid * 1.9 + cycle * 2.7);
	vec3 spawn;
	if (face < 0.4) {
		spawn = vec3(fr.x * halfS, halfS, fr.y * halfS);
	} else if (face < 0.55) {
		spawn = vec3(halfS, fr.y * halfS, fr.x * halfS);
	} else if (face < 0.7) {
		spawn = vec3(-halfS, fr.y * halfS, fr.x * halfS);
	} else if (face < 0.85) {
		spawn = vec3(fr.x * halfS, fr.y * halfS, halfS);
	} else {
		spawn = vec3(fr.x * halfS, fr.y * halfS, -halfS);
	}
	spawn += cube.xyz;

	// 움직임: 떠오르며 소용돌이, 바깥으로 천천히 퍼짐
	float secs = age * life;
	float rise = uPart.y * mix(0.6, 1.4, r3) * mix(1.0, 0.55, kind);
	vec3 pos = spawn;
	pos.y += secs * rise;
	float swirl = secs * mix(0.6, 1.3, r4) + r1 * 6.2832;
	float radius = uPart.z * age * mix(0.4, 1.0, r2);
	pos.x += sin(swirl) * radius + sin(t * 0.37 + r3 * 9.0) * 0.05 * age;
	pos.z += cos(swirl * 0.9) * radius;
	vec2 outward = normalize(spawn.xz + vec2(1e-3));
	pos.xz += outward * age * 0.18;
	pos.xz += outward * uHits.x * 0.08 * (1.0 - age);
	pos.y += uHits.x * 0.04 * (1.0 - age);

	// 보이기: 태어나고 사라질 때 서서히, 조용한 부분에서는 일부만
	float env = smoothstep(0.0, 0.08, age) * smoothstep(1.0, 0.55, age);
	float visible = step(r3, 0.3 + 0.7 * uHits.z);

	// 크기와 밝기
	float size = mix(mix(0.006, 0.018, r4), mix(0.03, 0.05, r4), kind);
	size *= uPart.x * (0.75 + 0.6 * uAudio.x + 0.4 * uHits.x * (1.0 - kind));
	float twinkle = 0.5 + 0.5 * sin(t * mix(8.0, 22.0, r4) + r1 * 30.0);
	float bright = (0.25 + 0.7 * uAudio.x + 1.2 * uHits.x * (1.0 - kind)) * mix(0.6, 1.0, kind);
	bright *= mix(1.0, mix(0.4, 1.6, twinkle), (1.0 - kind) * (0.3 + 0.7 * uAudio.w));

	vec3 col;
	if (kind > 0.5) {
		col = mix(mix(C_TEAL, C_LEAF, r3), C_AQUA, step(0.8, r4) * 0.6);
	} else {
		col = mix(C_SUN, C_AQUA, r4);
	}
	oVert.color = vec4(col * bright, env * visible);

	// 카메라를 향한 사각형. 잎은 천천히 돈다
	vec2 q = TDPos().xy;
	float ang = kind * (t * mix(0.4, 1.2, r2) + r1 * 6.2832);
	q = mat2(cos(ang), -sin(ang), sin(ang), cos(ang)) * q;
	int camIdx = TDCameraIndex();
	mat4 camInv = uTDMats[camIdx].camInverse;
	vec3 right = normalize(camInv[0].xyz);
	vec3 up = normalize(camInv[1].xyz);
	vec3 world = pos + (right * q.x + up * q.y) * size * (env * visible > 0.0 ? 1.0 : 0.0);

	oVert.uv = TDPos().xy;
	oVert.kind = kind;
	oVert.cameraIndex = camIdx;
	gl_Position = TDWorldToProj(vec4(world, 1.0));

#ifndef TD_PICKING_ACTIVE
#else
	TDWritePickingValues();
#endif
}
