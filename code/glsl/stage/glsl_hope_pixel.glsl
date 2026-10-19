// stage/glsl_hope — 프로젝터 콘텐츠: 장면 A "청춘의 청록" (render_projector에서만 쓴다)
//
// 프로젝터 시점에서 큐브 면마다 그릴 그림을 만든다. 이 그림이 그대로 실제 프로젝터로 나간다.
// 면마다 장(chapter)이 바뀔 때 세 가지 중 하나를 보여 준다.
//   회랑   면 안쪽으로 이어지는 숲길. 연한 청록 프레임이 계속 다가온다 (= 앞으로 나아감, 미래)
//          프레임은 군데군데 끊기고 어긋나 있다 (= 불확실함). 끝에는 빛이 있다
//   숲빛   나뭇잎 사이로 드는 햇살. 여러 큐브에 이어서 흐른다
//   여백   어두운 청록 바탕에 얇은 프레임 하나. 화면이 숨 쉬는 자리
// 공통: 모서리의 얇은 연청록 선(킥), 큐브를 가로지르는 햇살 띠
// 바닥·벽은 검정 (프로젝터가 큐브 밖은 비추지 않음)
//
// 색 버퍼: 0 = 콘텐츠, 1 = 파티클 잔상용(검정), 2 = (프로젝터까지 거리, 큐브 마스크)

uniform vec4 uAudio;  // x level, y low, z mid, w high
uniform vec4 uHits;   // x kick, y hit, z energy
uniform vec4 uClock;  // x time, y 회랑 위상, z flow, w 장(chapter) 위상
uniform vec4 uLook;   // x 밝기, y 모서리 선 두께(m), z 회랑 프레임 밀도, w 햇살 위상
uniform vec4 uProj;   // xyz 프로젝터 위치

in Vert {
	vec3 worldPos;
	vec3 objPos;
	flat float cubeSize;
	flat float seed;
	flat float isFloor;
	flat int cameraIndex;
} iVert;

layout(location = 0) out vec4 oFragColor[TD_NUM_COLOR_BUFFERS];

// 청춘의 청록 팔레트
const vec3 C_INK = vec3(0.006, 0.026, 0.030);   // 청록빛 어둠
const vec3 C_DEEPT = vec3(0.020, 0.180, 0.190); // 깊은 청록
const vec3 C_TEAL = vec3(0.060, 0.560, 0.540);  // 청록
const vec3 C_MOSS = vec3(0.090, 0.380, 0.270);  // 청록빛 이끼
const vec3 C_LEAF = vec3(0.360, 0.740, 0.540);  // 햇빛 받은 잎 (청록 쪽)
const vec3 C_AQUA = vec3(0.740, 0.950, 0.910);  // 연청록 (프레임)
const vec3 C_TURQ = vec3(0.100, 0.780, 0.800);  // 글리치 청록
const vec3 C_SUN = vec3(1.000, 0.920, 0.740);   // 햇살
const vec3 C_EARTH = vec3(0.520, 0.400, 0.290); // 흙길
const vec3 C_BARK = vec3(0.180, 0.110, 0.070);  // 나무 기둥

float Hash(vec2 p)
{
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float Noise(vec3 p)
{
	return TDSimplexNoise(p) * 0.5 + 0.5;
}

float Fbm(vec3 p)
{
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * Noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s / 0.9375;
}

void WriteOut(vec3 col, float mask)
{
	float dist = length(iVert.worldPos - uProj.xyz);
	oFragColor[0] = TDOutputSwizzle(vec4(col, 1.0));
#if TD_NUM_COLOR_BUFFERS > 1
	oFragColor[1] = TDOutputSwizzle(vec4(0.0, 0.0, 0.0, 1.0));
#endif
#if TD_NUM_COLOR_BUFFERS > 2
	oFragColor[2] = TDOutputSwizzle(vec4(dist, mask, 0.0, 1.0));
#endif
}

// 회랑: q는 면 좌표(-0.5~0.5)
vec3 Corridor(vec2 q, float seed, float t)
{
	vec2 vp = vec2(0.10 * sin(t * 0.06 + seed * 6.28), -0.07 + 0.05 * cos(t * 0.045 + seed * 4.0));
	vec2 d = q - vp;
	float c = max(max(abs(d.x), abs(d.y)), 0.004);
	float z = 0.5 / c;                       // 깊이 (면 가장자리 ≈ 1, 소실점으로 갈수록 커짐)
	float density = uLook.z * mix(0.75, 1.35, seed);   // 면마다 프레임 간격이 다르다
	float zz = z * density + uClock.y * mix(0.8, 1.25, fract(seed * 7.3));  // 위상이 늘면 프레임이 다가온다
	float zs = zz / density;                 // 벽 무늬가 프레임과 같이 흘러오게 하는 좌표
	float k = floor(zz);
	float f = fract(zz);
	bool side = abs(d.x) > abs(d.y);
	float across = side ? d.y / c : d.x / c; // 벽을 가로지르는 좌표 (-1~1)
	float fog = exp(-z * 0.16);

	vec3 col;
	if (!side && d.y < 0.0) {
		// 바닥: 가운데 흙길, 양옆 풀
		float path = smoothstep(0.62, 0.36, abs(across));
		float stone = Fbm(vec3(across * 3.0, zs * 1.4, seed));
		vec3 earth = mix(C_EARTH * 0.45, C_EARTH, stone);
		float grassN = Fbm(vec3(across * 8.0, zs * 3.5, seed + 3.0));
		vec3 grass = mix(C_INK, C_MOSS, grassN) + C_LEAF * smoothstep(0.7, 0.9, grassN) * 0.4;
		col = mix(grass, earth, path);
	} else if (!side) {
		// 천장: 잎 사이로 보이는 하늘빛
		float leaf = Fbm(vec3(across * 4.0, zs * 1.6, seed + 7.0));
		col = mix(mix(C_INK, C_DEEPT, leaf), C_AQUA * 0.9, smoothstep(0.58, 0.78, leaf));
	} else {
		// 옆벽: 나무 기둥 사이로 잎
		float leaves = Fbm(vec3(across * 5.0, zs * 2.2, seed + 11.0));
		col = mix(mix(C_INK, C_MOSS, leaves), C_LEAF, smoothstep(0.66, 0.88, leaves));
		float trunkPos = fract(zs * 0.8 + seed);
		float trunk = smoothstep(0.10, 0.04, abs(trunkPos - 0.5));
		col = mix(col, C_BARK * (0.6 + 0.6 * Fbm(vec3(across * 20.0, zs, seed))), trunk * 0.85);
	}

	// 깊이 안개: 멀어질수록 청록으로 잠기고, 소실점에는 빛
	col = mix(C_TEAL * 0.5, col, fog);
	col += mix(C_AQUA, C_SUN, 0.5) * exp(-c * 16.0) * (0.45 + 1.1 * uAudio.y);

	// 프레임: 연청록 회벽 질감. 군데군데 끊기고, 프레임마다 조금씩 어긋난다
	float aa = fwidth(zz);
	float fw = 0.22;
	float band = smoothstep(fw + aa, fw - aa, f) * smoothstep(0.0, aa + 0.01, f);
	float perim = side ? d.y / c : d.x / c;
	float slot = floor((perim + 1.0) * 3.5 + Hash(vec2(k, seed)) * 3.0);
	float keep = step(0.24, Hash(vec2(k * 1.3, slot + seed * 7.0)));
	vec3 plaster = C_AQUA * (0.75 + 0.25 * Fbm(vec3(q * 28.0, k)));
	plaster = mix(plaster, C_TURQ, step(0.88, Hash(vec2(k * 3.1, slot))) * 0.7);
	float near = 1.0 - fog;
	col = mix(col, plaster * mix(1.0, 0.45, near), band * keep);
	return col;
}

// 숲빛: 나뭇잎 사이 햇살. pc는 큐브를 넘어 이어지는 월드 좌표
vec3 Canopy(vec2 pc, float seed, float t)
{
	vec2 wind = vec2(t * 0.05, sin(t * 0.31) * 0.04);
	float l1 = Fbm(vec3(pc * 2.1 + wind, t * 0.04));
	float l2 = Fbm(vec3(pc * 4.6 - wind * 1.7, t * 0.07 + 5.0));
	float leaf = l1 * 0.6 + l2 * 0.4;
	vec3 col = mix(C_INK, C_DEEPT, smoothstep(0.25, 0.6, leaf));
	col = mix(col, C_TEAL * 0.8, smoothstep(0.48, 0.62, leaf) * 0.6);
	float gap = smoothstep(0.66, 0.70, leaf);
	float rim = smoothstep(0.60, 0.66, leaf) * (1.0 - gap);
	col += C_LEAF * rim * 0.35;
	col += mix(C_AQUA, C_SUN, 0.45) * gap * (0.45 + 0.9 * uAudio.z);
	return col;
}

// 여백: 어두운 청록 바탕, 얇은 프레임 하나, 지나가는 잎 그림자
vec3 Quiet(vec2 q, vec2 pc, float seed, float t)
{
	float grain = Fbm(vec3(q * 12.0, seed + t * 0.02));
	vec3 col = mix(C_INK, C_DEEPT * 1.3, grain);
	float inset = 0.34 + 0.03 * sin(t * 0.35 + seed * 6.0);
	float r = abs(max(abs(q.x), abs(q.y)) - inset);
	col += C_AQUA * smoothstep(0.005 + fwidth(r), 0.0, r) * 0.8;
	float shadow = Fbm(vec3(pc * 1.3 + vec2(t * 0.05, 0.0), seed));
	return col * mix(0.5, 1.0, smoothstep(0.35, 0.6, shadow));
}

vec3 FaceContent(float mode, vec2 q, vec2 pc, float seed, float t)
{
	if (mode < 0.5) {
		return Corridor(q, seed, t);
	} else if (mode < 1.5) {
		return Canopy(pc, seed, t);
	}
	return Quiet(q, pc, seed, t);
}

float PickMode(float faceSeed, float chapter)
{
	float h = Hash(vec2(faceSeed * 17.3, chapter * 1.91));
	float corridorShare = 0.3 + 0.3 * uHits.z;     // 곡이 클수록 회랑이 많아짐
	if (h < corridorShare) {
		return 0.0;
	}
	return h < corridorShare + 0.35 ? 1.0 : 2.0;
}

void main()
{
	TDCheckDiscard();
	float t = uClock.x;
	vec3 wp = iVert.worldPos;

	if (iVert.isFloor > 0.5) {
		WriteOut(vec3(0.0), 0.0);
		return;
	}

	// 면 판별: 로컬 좌표에서 절대값이 가장 큰 축이 그 면의 법선 방향
	vec3 p = iVert.objPos;
	vec3 ap = abs(p);
	vec2 q;
	float faceId;
	vec3 nLocal;
	if (ap.x >= ap.y && ap.x >= ap.z) {
		q = vec2(-p.z * sign(p.x), p.y); faceId = p.x > 0.0 ? 0.0 : 1.0; nLocal = vec3(sign(p.x), 0.0, 0.0);
	} else if (ap.y >= ap.z) {
		q = vec2(p.x, -p.z * sign(p.y)); faceId = p.y > 0.0 ? 2.0 : 3.0; nLocal = vec3(0.0, sign(p.y), 0.0);
	} else {
		q = vec2(p.x * sign(p.z), p.y); faceId = p.z > 0.0 ? 4.0 : 5.0; nLocal = vec3(0.0, 0.0, sign(p.z));
	}
	float s = iVert.cubeSize;
	float faceSeed = Hash(vec2(iVert.seed * 91.7, faceId * 13.1));
	vec2 pc = abs(nLocal.y) > 0.5 ? wp.xz : vec2(wp.x + wp.z, wp.y);

	// 장 바꾸기: 면마다 회랑/숲빛/여백 중 하나. 바뀔 때 잠깐 섞인다
	float chapter = floor(uClock.w);
	float blend = smoothstep(0.0, 0.12, fract(uClock.w));
	float modeNow = PickMode(faceSeed, chapter);
	vec3 col = FaceContent(modeNow, q, pc, faceSeed, t);
	if (blend < 1.0) {
		float modePrev = PickMode(faceSeed, chapter - 1.0);
		vec3 prev = FaceContent(modePrev, q, pc, faceSeed, t);
		col = mix(prev, col, blend);
	}

	// 큐브를 가로지르는 햇살 띠
	float sunPos = fract(uLook.w) * 5.0 - 1.5;
	float sunD = dot(wp, normalize(vec3(0.8, -0.35, 0.45))) - sunPos;
	col += C_SUN * exp(-sunD * sunD / 0.02) * (0.12 + 0.5 * uAudio.y);

	// 모서리 선: 얇은 연청록, 킥에 맞춰 밝아짐
	float edgeDist = (0.5 - max(abs(q.x), abs(q.y))) * s;
	float w = uLook.y;
	float edge = smoothstep(w + fwidth(edgeDist), 0.0, edgeDist);
	col = mix(col, C_AQUA * (0.5 + 1.2 * uHits.x), edge * 0.85);

	col *= uLook.x * (0.5 + 0.5 * uHits.z);
	WriteOut(col, 1.0);
}
