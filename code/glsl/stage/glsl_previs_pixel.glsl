// stage/glsl_previs — 프로젝터 빛 시뮬레이션
// 프로젝터 출력(null_projector)을 프로젝터 위치에서 장면에 투사한다.
//   - 프로젝터를 향한 면만 밝고, 비스듬할수록 어두워진다 (입사각)
//   - 다른 큐브에 가린 곳은 그림자 (프로젝터 시점 거리 버퍼와 비교)
//   - 멀수록 어두워진다 (거리 제곱)
//   - 프로젝터의 검정도 완전한 검정이 아니라서, 비추는 범위 안의 바닥·벽이 아주 희미하게 밝다
// 방은 거의 어둡고, 흰 큐브의 빛이 안 닿는 면은 겨우 보이는 정도.

uniform mat4 uProjVP;    // 프로젝터 view-projection
uniform vec4 uProjPos;   // xyz 프로젝터 위치, w 그림자 여유값(m)
uniform vec4 uRoom;      // x 방 조명, y 프로젝터 검정 레벨, z 프로젝터 밝기, w 기준 거리(m)
uniform vec4 uMisc;      // x 큐브 개수, y 접촉 그림자 세기
uniform sampler2D sProj;      // null_projector
uniform sampler2D sProjDist;  // renderselect_pdist (r = 프로젝터까지 거리)
uniform samplerBuffer uCubes; // 큐브마다 (tx, ty, tz, s)

in Vert {
	vec3 worldPos;
	vec3 objPos;
	flat float isRoom;
	flat int cameraIndex;
} iVert;

layout(location = 0) out vec4 oFragColor[TD_NUM_COLOR_BUFFERS];

float Hash(vec2 p)
{
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main()
{
	TDCheckDiscard();
	vec3 wp = iVert.worldPos;
	vec3 n = normalize(cross(dFdx(wp), dFdy(wp)));
	vec3 camPos = uTDMats[iVert.cameraIndex].camInverse[3].xyz;
	if (dot(n, camPos - wp) < 0.0) {
		n = -n;
	}

	// 프로젝터 빛
	vec3 light = vec3(0.0);
	vec4 clip = uProjVP * vec4(wp, 1.0);
	if (clip.w > 0.0) {
		vec2 puv = clip.xy / clip.w * 0.5 + 0.5;
		if (all(greaterThanEqual(puv, vec2(0.0))) && all(lessThanEqual(puv, vec2(1.0)))) {
			vec3 toProj = uProjPos.xyz - wp;
			float dist = length(toProj);
			vec3 L = toProj / dist;
			float stored = texture(sProjDist, puv).r;
			float visible = stored <= 0.0 ? 1.0 : step(dist, stored + uProjPos.w);
			float ndl = max(dot(n, L), 0.0);
			vec3 pc = texture(sProj, puv).rgb + uRoom.y;
			light = pc * ndl * visible * uRoom.z * pow(uRoom.w / dist, 2.0);
		}
	}

	// 재질: 흰 무광 큐브 / 어두운 콘크리트 바닥·벽
	vec3 albedo;
	if (iVert.isRoom > 0.5) {
		float grain = 0.75 + 0.25 * Hash(floor(wp.xz * 60.0 + wp.y * 37.0));
		albedo = vec3(0.13, 0.135, 0.13) * grain;
	} else {
		albedo = vec3(0.86, 0.87, 0.85);
	}
	// 접촉 그림자: 바닥은 큐브 발밑 근처, 큐브는 바닥·아래 큐브에 닿는 아랫부분이 어두워진다
	float ao = 1.0;
	int numCubes = int(uMisc.x);
	for (int i = 0; i < numCubes; i++) {
		vec4 cube = texelFetch(uCubes, i);
		float h = cube.w * 0.5;
		vec3 rel = wp - cube.xyz;
		vec3 dBox = abs(rel) - vec3(h);
		float outside = length(max(dBox, 0.0));
		float below = rel.y + h;  // 이 큐브 바닥면에서 위로 잰 높이
		if (iVert.isRoom > 0.5) {
			ao *= mix(0.35, 1.0, smoothstep(0.0, 0.35, outside));
		} else if (outside > 0.001) {
			ao *= mix(0.55, 1.0, smoothstep(0.0, 0.25, outside));
		}
	}
	if (iVert.isRoom < 0.5) {
		ao *= mix(0.6, 1.0, smoothstep(0.0, 0.3, wp.y));
	}
	ao = mix(1.0, ao, uMisc.y);

	float ambient = uRoom.x * (0.55 + 0.45 * max(n.y, 0.0)) * ao;
	vec3 col = albedo * (ambient + light * mix(1.0, ao, 0.4));

	oFragColor[0] = TDOutputSwizzle(vec4(col, 1.0));
}
