// stage/glsl_hope — 큐브·바닥 공용 정점 셰이더 (장면 A: 희망)
// 큐브는 table_cubes로 인스턴싱된 단위 박스(-0.5~0.5), 바닥은 16m 사각형이다.

out Vert {
	vec3 worldPos;
	vec3 objPos;          // 박스 로컬 좌표 (-0.5~0.5). 면 UV와 모서리 거리 계산용
	flat float cubeSize;  // 큐브 한 변 길이 (월드 m)
	flat float seed;      // 큐브마다 다른 난수
	flat float isFloor;
	flat int cameraIndex;
} oVert;

void main()
{
	vec3 pos = TDPos();
	vec4 worldPos = TDDeform(pos);
	vec3 origin = TDDeform(vec3(0.0)).xyz;

	oVert.worldPos = worldPos.xyz;
	oVert.objPos = pos;
	oVert.cubeSize = length(TDDeform(vec3(1.0, 0.0, 0.0)).xyz - origin);
	oVert.seed = fract(sin(float(TDInstanceID()) * 12.9898 + 4.1) * 43758.5453);
	oVert.isFloor = max(abs(pos.x), abs(pos.z)) > 0.75 ? 1.0 : 0.0;
	oVert.cameraIndex = TDCameraIndex();
	gl_Position = TDWorldToProj(worldPos);

#ifndef TD_PICKING_ACTIVE
#else
	TDWritePickingValues();
#endif
}
