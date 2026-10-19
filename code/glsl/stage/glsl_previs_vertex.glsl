// stage/glsl_previs — 미리보기용 재질 (render_view의 Override Material)
// 어두운 합주실의 흰 큐브·바닥·벽이 프로젝터 빛을 받는 모습을 흉내 낸다.

out Vert {
	vec3 worldPos;
	vec3 objPos;
	flat float isRoom;
	flat int cameraIndex;
} oVert;

void main()
{
	vec3 pos = TDPos();
	vec4 worldPos = TDDeform(pos);
	oVert.worldPos = worldPos.xyz;
	oVert.objPos = pos;
	oVert.isRoom = max(abs(pos.x), max(abs(pos.y), abs(pos.z))) > 0.75 ? 1.0 : 0.0;
	oVert.cameraIndex = TDCameraIndex();
	gl_Position = TDWorldToProj(worldPos);

#ifndef TD_PICKING_ACTIVE
#else
	TDWritePickingValues();
#endif
}
