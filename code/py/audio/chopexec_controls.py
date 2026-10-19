# audio/chopexec_controls — 발표용 키보드 조작
# Perform 창(/project1 패널)에 포커스가 있을 때만 동작한다 (keyboardin_controls의 Panels).
#   P  재생 / 일시정지
#   R  처음부터 다시 재생
#   V  화면 바꾸기: 미리보기 → 프로젝터 출력 → 미리보기 + 프로젝터 작은 화면


def onOffToOn(channel, sampleIndex, val, prev):
	audio = parent()
	if channel.name == 'p':
		audio.par.Play = not audio.par.Play.eval()
	elif channel.name == 'r':
		audio.par.Restart.pulse()
		audio.par.Play = True
	elif channel.name == 'v':
		view = parent.Project.op('stage').par.View
		view.menuIndex = (view.menuIndex + 1) % len(view.menuNames)
	return


def whileOn(channel, sampleIndex, val, prev):
	return


def onOnToOff(channel, sampleIndex, val, prev):
	return


def whileOff(channel, sampleIndex, val, prev):
	return


def onValueChange(channel, sampleIndex, val, prev):
	return
