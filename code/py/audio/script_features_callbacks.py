# audio/script_features — 원곡 스펙트럼에서 시각화용 특징값을 만든다.
#
# 입력: audiospectrum_song (visual 모드, 선형 주파수, 채널마다 1024샘플 ≈ 21.5Hz 간격)
# 출력 채널 (모두 0~1, 프레임당 1샘플):
#   level   전체 크기          (최근 몇 초의 최소~최대 범위로 정규화 → 반응용)
#   low     저음 25~150Hz      (킥, 베이스)
#   mid     중음 250~2000Hz    (기타, 보컬)
#   high    고음 4~12kHz       (심벌, 하이햇)
#   kick    저음 어택          (킥에서 1 근처로 튀고 빠르게 줄어듦)
#   hit     전체 어택          (스트럼·스네어 등, 스펙트럼 플럭스 기준)
#   energy  곡의 큰 흐름       (몇 초 평균을 긴 범위로 정규화 → 조용한 부분은 낮게)
#
# 반응용 값은 최근 범위(바닥~피크)로 정규화하기 때문에 소리가 계속 커도 1에 붙지 않는다.
# 조용한 부분과 큰 부분의 차이는 energy로 표현한다.

import numpy as np

BANDS = {
	'level': (30.0, 12000.0),
	'low': (25.0, 150.0),
	'mid': (250.0, 2000.0),
	'high': (4000.0, 12000.0),
}
KICK_BAND = (30.0, 160.0)
HIT_BAND = (160.0, 9000.0)

RANGE_TIME = 4.0      # 반응용 범위(바닥·피크)가 따라오는 시간(초)
ENERGY_AVG = 3.0      # energy 평균 시간(초)
ENERGY_RANGE = 45.0   # energy 범위가 따라오는 시간(초)
GAMMA = 1.4           # 큰 값만 도드라지게
ATTACK, RELEASE = 0.015, 0.14
ONSET_DECAY = 0.22    # kick/hit가 줄어드는 시간(초)
ONSET_GAP = {'kick': 0.16, 'hit': 0.11}
ONSET_RATIO = 1.8     # 평균 플럭스보다 이만큼 커야 어택으로 봄
ONSET_FLOOR = 0.3     # 최근 최대 플럭스의 이 비율보다는 커야 함

S = {}  # 프레임 사이 상태. 파일을 다시 읽으면 초기화된다.


def _coef(tc, dt):
	return 1.0 - np.exp(-dt / max(tc, 1e-4))


def _slice(lo, hi, hz, n):
	i0 = max(int(lo / hz), 1)
	i1 = min(max(int(hi / hz), i0 + 1), n)
	return slice(i0, i1)


def _range_norm(key, raw, tc, dt, min_span):
	# 바닥은 내려갈 때 바로, 올라갈 때 천천히 / 피크는 그 반대
	lo = S['lo'].get(key, raw)
	hi = S['hi'].get(key, raw)
	lo = raw if raw < lo else lo + (raw - lo) * _coef(tc, dt)
	hi = raw if raw > hi else hi + (raw - hi) * _coef(tc, dt)
	S['lo'][key], S['hi'][key] = lo, hi
	span = max(hi - lo, min_span)
	return min(max((raw - lo) / span, 0.0), 1.0)


def onSetupParameters(scriptOp):
	return


def onPulse(par):
	return


def onCook(scriptOp):
	scriptOp.clear()
	spec = scriptOp.inputs[0]
	src = spec.inputs[0] if spec.inputs else None
	rate = src.rate if src is not None else 44100.0
	dt = min(max(absTime.stepSeconds, 1.0 / 240.0), 0.1)

	comp = scriptOp.parent()
	sens = comp.par.Sensitivity.eval() if hasattr(comp.par, 'Sensitivity') else 1.0

	mag = spec.numpyArray()
	names = list(BANDS) + ['kick', 'hit', 'energy']
	scriptOp.numSamples = 1
	chans = {name: scriptOp.appendChan(name) for name in names}
	if mag.size == 0:
		return

	mag = mag.mean(axis=0)
	n = mag.shape[0]
	hz = rate * 0.5 / n
	lm = np.log1p(mag * 50.0)

	if S.get('n') != n:
		S.clear()
		S.update(n=n, prev=lm.copy(), env={}, lo={}, hi={}, onset={}, flux_avg={},
				flux_peak={}, since={}, energy=None)

	out = {}

	# 대역 크기 → 최근 범위로 정규화 → 감마 → 어택/릴리즈 스무딩
	for name, (lo, hi) in BANDS.items():
		raw = float(lm[_slice(lo, hi, hz, n)].mean())
		target = min(_range_norm(name, raw, RANGE_TIME, dt, 0.02) * sens, 1.0) ** GAMMA
		prev = S['env'].get(name, 0.0)
		tc = ATTACK if target > prev else RELEASE
		val = prev + (target - prev) * _coef(tc, dt)
		S['env'][name] = val
		out[name] = val

	# 어택: 스펙트럼 플럭스(양의 변화량 평균)가 최근 평균보다 확 커질 때
	diff = np.clip(lm - S['prev'], 0.0, None)
	S['prev'] = lm
	for name, (lo, hi) in (('kick', KICK_BAND), ('hit', HIT_BAND)):
		flux = float(diff[_slice(lo, hi, hz, n)].mean())
		avg = S['flux_avg'].get(name, flux)
		fpeak = max(flux, S['flux_peak'].get(name, flux) * np.exp(-dt / RANGE_TIME), 1e-5)
		S['flux_peak'][name] = fpeak
		since = S['since'].get(name, 1.0) + dt
		env = S['onset'].get(name, 0.0) * np.exp(-dt / ONSET_DECAY)
		if (flux > avg * ONSET_RATIO and flux > fpeak * ONSET_FLOOR / sens
				and since > ONSET_GAP[name]):
			strength = min(max((flux - avg) / fpeak, 0.0), 1.0)
			env = max(env, 0.5 + 0.5 * strength)
			since = 0.0
		S['flux_avg'][name] = avg + (flux - avg) * _coef(0.3, dt)
		S['since'][name] = since
		S['onset'][name] = env
		out[name] = env

	# 에너지: 몇 초 평균을 긴 범위로 정규화
	full = float(lm[_slice(*BANDS['level'], hz, n)].mean())
	e = full if S['energy'] is None else S['energy'] + (full - S['energy']) * _coef(ENERGY_AVG, dt)
	S['energy'] = e
	out['energy'] = _range_norm('energy', e, ENERGY_RANGE, dt, 0.05)

	for name, ch in chans.items():
		ch[0] = out[name]
	return
