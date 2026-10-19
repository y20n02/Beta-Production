# Beta-Production — TouchDesigner 프로젝트 가이드

TouchDesigner 프로젝트 레포(`y20n02/Beta-Production`, 공개 레포)입니다.
Claude Code는 Derivative의 공식 MCP인 **TDMCP**로 실행 중인 TouchDesigner에 연결해 작업합니다.

## MCP 연결

| 항목 | 값 |
|---|---|
| MCP 서버 | TDMCP (Derivative, 베타) — https://github.com/TouchDesigner/TDMCP |
| 주소 | `http://127.0.0.1:13316/mcp` (HTTP, localhost 전용) |
| 등록 위치 | 이 레포의 `.mcp.json` (project 범위, 서버 이름 `touchdesigner`) |
| 필요 TD 버전 | 2025.33070 이상 |
| 스킬 | TDMCPSkills의 `td-*` 스킬 19개 → `.claude/skills/` (git 제외) |

- `localhost`가 아니라 `127.0.0.1`을 씁니다. TDMCP 소켓은 IPv4 전용입니다.
- 등록은 `.mcp.json`이 담당하므로 TDMCP MCP 페이지의 **Add MCP** 명령은 실행하지 않습니다.
- TDMCP는 `Beta.toe` 안(`/TDMCP`)에 포함돼 있습니다. 따로 받은 `TDMCP.tox` 파일은 git에 올리지 않습니다.

## 새 PC 셋업 순서

1. TouchDesigner 2025.33070 이상 설치 (라이선스 Update Date 확인)
2. 레포 클론 (새 `.toe`에 TDMCP를 넣을 때만 [TDMCP Releases](https://github.com/TouchDesigner/TDMCP/releases)에서 `TDMCP.tox`를 받음)
3. TD에서 `Beta.toe`를 열고 `/TDMCP` 컴포넌트의 MCP 페이지에서 **Active** 켜기 (`.toe` 안에 이미 들어 있음. 버전 업데이트는 About 페이지의 **Update**)
4. MCP 페이지: Install For = Claude Code, Install Scope = 프로젝트 → **Install Skills**
5. 이 폴더에서 Claude Code 실행 → `touchdesigner` 서버 사용 승인 → `claude mcp list`로 확인

## Claude 작업 규칙

- TD 작업 전 `td-general` 스킬을 먼저 불러옵니다. 빌드 순서: `td-build-planning` → 빌더 스킬 → `td-review-network` → `td-network-cleanup`.
- 사용자가 요청하지 않은 수정은 하지 않습니다. 분석/검토 요청이면 읽기만 합니다.
- 오퍼레이터 삭제, 대량 변경, `execute_code`로 파일·시스템을 건드리는 작업은 먼저 확인받습니다.
  (`execute_code`는 셸 접근과 비슷한 권한이고, TDMCP는 기본값으로 삭제를 자동 승인합니다.)
- TDMCP는 도구 호출 1번 = Undo 1단계입니다. 문제가 생기면 TD에서 `Ctrl+Z`로 되돌릴 수 있다고 안내합니다.

## 프로젝트 파일과 저장 방식

- 메인 파일은 `Beta.toe`입니다. TDMCP 컴포넌트는 `/TDMCP`에 들어 있습니다.
- TD 기본 설정상 저장할 때마다 번호 버전(`Beta.1.toe`, `Beta.2.toe` …)이 생기고, 동시에 `Beta.toe`가 최신 저장본으로 갱신됩니다. 그래서 TD 창 제목에는 번호 붙은 이름이 보이는 게 정상입니다.
- git에는 `Beta.toe`만 올리고, 번호 버전과 `Backup/`은 제외합니다.
- 사용자가 저장/종료를 언급하면, 저장 후 `Beta.toe`가 최신인지(번호 버전과 수정 시각이 같은지) 확인하도록 알려 줍니다.

```powershell
Get-Process -Name TouchDesigner | Select-Object Id, MainWindowTitle
```

## 연결 문제 해결 순서

1. TouchDesigner가 켜져 있고 TDMCP 컴포넌트의 **Active**가 켜져 있는지 확인
2. 포트 확인: `Get-NetTCPConnection -LocalPort 13316 -State Listen`
3. 엔드포인트 확인: `curl -i http://127.0.0.1:13316/mcp` (JSON 응답 또는 인증 사용 시 401이면 서버 정상)
4. `claude mcp list`에서 `touchdesigner`가 위 주소를 가리키는지, 같은 이름의 예전 서버(stdio `node ...td-mcp-server`, 포트 9980/9981, `npx touchdesigner-mcp-server`)가 남아 있지 않은지 확인
5. Claude Code 재시작 (`/exit` 후 다시 실행)
6. 스킬이 안 보이면: MCP 페이지 Skills Status / Installed Locations와 실행 폴더 범위가 맞는지 확인
7. Install Skills에서 `CERTIFICATE_VERIFY_FAILED`가 나면: TDMCPSkills를 로컬에 클론하고 **Skills Source**를 그 폴더로 지정

## 예전 MCP (사용 중지)

- 직접 만든 Node 서버: `C:\Users\PC\Documents\TeamFossil\td_mcp\td-mcp-server` (WebSocket 9980, 도구 8개). 2026-10-19에 Claude Code 등록 해제, 코드는 보관.
- 예전 `.toe` 안에 `mcp_webserver`, `mcp_handler` 같은 노드가 남아 있을 수 있습니다. 위치만 알려 주고 지우지 않습니다.

## 라이선스

TDMCP © Derivative Inc. — Shared Use License. TouchDesigner와 함께 쓰는 용도로만 사용하며, TDMCP 자체를 재배포하지 않습니다.
