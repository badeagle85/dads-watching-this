<div align="center">

<img src="docs/images/app-icon.png" width="128" alt="아빠안잔다">

# 아빠안잔다

**AI 세션이 도는 동안 맥을 안 재우는 macOS 메뉴바 앱**<br>
지키고 있는지를 아이콘 모양만 보고 안다

[![Release](https://img.shields.io/github/v/release/badeagle85/dads-watching-this?style=flat-square&color=2d4169)](https://github.com/badeagle85/dads-watching-this/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/badeagle85/dads-watching-this/total?style=flat-square&color=2d4169)](https://github.com/badeagle85/dads-watching-this/releases)
![Platform](https://img.shields.io/badge/macOS-14%2B-2d4169?style=flat-square)
[![License](https://img.shields.io/github/license/badeagle85/dads-watching-this?style=flat-square&color=2d4169)](LICENSE)

<table>
<tr>
<td align="center"><img src="docs/images/state-sleeping.png" width="54"><br><b>잔다</b><br><sub>안 걸렸다</sub></td>
<td align="center"><img src="docs/images/state-awake.png" width="54"><br><b>안 잔다</b><br><sub>깨워 두는 중</sub></td>
<td align="center"><img src="docs/images/state-session.png" width="54"><br><b>세션 지키는 중</b><br><sub>끝나면 풀린다</sub></td>
<td align="center"><img src="docs/images/state-lid.png" width="54"><br><b>테두리</b><br><sub>뚜껑 설정 켜짐</sub></td>
</tr>
</table>

</div>

---

## 왜 만들었나

Claude Code 를 돌려 놓고 자리를 비우면 **세션이 살아 있는지 알 수가 없다.** 돌아와 보면 끊겨 있고, 언제 왜 끊겼는지도 모른다.

`caffeinate` 를 감싸는 앱은 이미 여럿 있지만, 전부 **켜짐/꺼짐 두 단계**다. 이 앱은 두 가지를 더 한다.

| | |
|---|---|
| **상태가 형태로 보인다** | 메뉴바 아이콘은 색을 못 쓴다(template image). 그래서 윤곽·파동·채움 **세 모양**으로 나눴다 |
| **세션을 지목한다** | "30분" 이 아니라 **"이 세션이 끝날 때까지"**. 고른 세션이 끝나면 저절로 풀린다 |

## 설치

```bash
brew tap badeagle85/tap
brew trust badeagle85/tap
brew install --cask dads-watching-this
xattr -dr com.apple.quarantine /Applications/DadsWatchingThis.app
```

> [!IMPORTANT]
> **네 번째 줄을 앱을 열기 전에 실행해야 한다.**
> 격리 딱지가 붙은 채로 열면 macOS 가 "열 수 없다" 며 **앱을 지우라고 권하고, 확인을 누르면 앱이 사라진다.**
> 그때는 `brew reinstall --cask dads-watching-this` 로 다시 받은 뒤 위 순서대로 하면 된다.

[릴리스에서 zip 을 직접 받아도](https://github.com/badeagle85/dads-watching-this/releases/latest) 된다. `/Applications` 에 넣고 같은 `xattr` 명령을 실행한다.

## 쓰는 법

메뉴바 아이콘을 누르면 이게 전부다.

```
잔다
──────────────────────
화면 끄고 지키기
──────────────────────
언제까지 안 자나
✓ 끌 때까지
  30분 / 1시간 / 2시간
  세션이 끝날 때까지      ▸   makestar · 2시간
                             commerce-web · 18분
──────────────────────
✓ 배터리 20% 밑이면 잔다
✓ 뚜껑 닫아도 안 잔다…
  로그인할 때 자동 실행
  메뉴바 경과 시간        ▸   숨김 / 시:분 / 시:분:초
──────────────────────
  이제 잔다
  아이콘 읽는 법…
  종료                ⌘Q
```

| 항목 | 하는 일 |
|---|---|
| **화면 끄고 지키기** | 자리 비울 때 한 번으로. 유지를 켜고 화면을 끈다 |
| **언제까지 안 자나** | 끝나는 조건을 고른다. 세션을 고르면 그게 끝날 때 풀린다 |
| **배터리 20% 밑이면 잔다** | 충전기가 빠진 채 배터리가 줄면 스스로 푼다 |
| **뚜껑 닫아도 안 잔다** | 시스템 설정을 바꾼다. 암호는 macOS 가 받는다 |
| **메뉴바 경과 시간** | 아이콘 옆 숫자. 숨길 수도, 초까지 볼 수도 있다 |

전역 단축키 **⌥⌘L** 로 어느 앱에서든 켜고 끈다.

## 아이콘 읽는 법

| | 모양 | 뜻 |
|:---:|---|---|
| <img src="docs/images/state-sleeping.png" width="40"> | 윤곽 | **잔다** — 아무것도 안 걸렸다 |
| <img src="docs/images/state-awake.png" width="40"> | 윤곽 + 파동 | **안 잔다** — 깨워 두는 중 |
| <img src="docs/images/state-session.png" width="40"> | 채움 + 파동 | **세션 지키는 중** — 그 세션이 끝나면 풀린다 |
| <img src="docs/images/state-lid.png" width="40"> | **테두리** | 뚜껑 닫힘 시스템 설정이 켜져 있다 |

테두리는 세 모양 **어디에나** 붙는다. 앱 상태와 시스템 설정은 서로 다른 축이기 때문이다. 앱이 해제해도 시스템 설정은 남아 있을 수 있고, 그때도 테두리는 그대로다.

앱 안에서도 `아이콘 읽는 법…` 으로 같은 설명을 볼 수 있다.

## 기능

- [x] 메뉴바에서 상태 확인 (3가지 모양 × 테두리)
- [x] 끝나는 조건 선택 — 끌 때까지 / 30분 / 1시간 / 2시간 / **세션이 끝날 때까지**
- [x] Claude Code 세션 목록에서 지목 (최근 12시간, 폴더명으로 구분)
- [x] 화면 끄고 지키기
- [x] 뚜껑 닫힘 시스템 설정 읽기·쓰기
- [x] 끊김 이력 — 자리 비운 사이 잠들었으면 시각과 사유
- [x] 알림 3종 — 세션 종료 · 충전기 분리 · 배터리 해제
- [x] 배터리 20% 자동 해제
- [x] 로그인할 때 자동 실행
- [x] 전역 단축키 ⌥⌘L
- [ ] 영어 (지금은 한국어만)
- [ ] 자동 업데이트
- [ ] 고른 세션이 끝나면 다른 세션으로 이관
- [ ] Codex·Cursor 등 다른 에이전트 연동

## 자주 묻는 것

<details>
<summary><b>어떻게 동작하나?</b></summary><br>

Apple 이 macOS 에 기본으로 넣어 둔 `caffeinate` 명령을 감싼다. 유지를 켜면 이걸 띄운다.

```
/usr/bin/caffeinate -i -w <앱 PID>
```

`-i` 는 시스템 잠만 막는다. 화면은 평소대로 꺼진다 — 자리를 비우는 게 전제라 화면을 켜 둘 이유가 없다.

`-w <앱 PID>` 덕분에 **앱이 죽으면 `caffeinate` 도 같이 죽는다.** 강제 종료하거나 크래시가 나도 좀비가 안 남는다.
</details>

<details>
<summary><b>뚜껑을 닫아도 되나?</b></summary><br>

기본적으로는 안 된다. **`caffeinate` 로는 뚜껑 닫힘(Clamshell Sleep)을 못 막는다.** 실측으로 확인했다 — 충전기를 꽂고 외부 모니터를 빼도 뚜껑을 닫으면 5초 만에 잠든다.

막는 방법은 시스템 설정 하나뿐이다.

```bash
sudo pmset -a disablesleep 1   # 켜기
sudo pmset -a disablesleep 0   # 되돌리기
```

메뉴의 `뚜껑 닫아도 안 잔다…` 를 누르면 이걸 대신 실행한다. **암호는 macOS 가 직접 받고 앱은 보지 못한다.**

이 설정은 앱을 꺼도, 재부팅해도 남는다. 그래서 켜져 있는 동안 아이콘에 테두리가 붙는다 — 끄는 걸 잊고 가방에 넣으면 열이 차고 배터리가 빨리 준다.
</details>

<details>
<summary><b>설치할 때 왜 명령을 네 줄이나 치나?</b></summary><br>

이 앱이 **Apple 공증(notarization)을 받지 않았기** 때문이다. 공증에는 Apple Developer Program 연 $99 가 든다. 사용자가 생기기 전에 연회비부터 내는 건 순서가 거꾸로라 보고, 공증 대신 **소스를 전부 공개**하는 쪽을 택했다.

`xattr` 명령이 하는 일은 "이 파일은 인터넷에서 받았다"는 표시를 떼는 것뿐이다. Homebrew 가 예전에 `--no-quarantine` 옵션으로 해 주던 일인데, **Homebrew 7.0 에서 그 옵션이 제거됐다.**

`brew trust` 는 Homebrew 가 공식 저장소 밖의 설치 정의를 쓰기 전에 요구하는 확인이다.
</details>

<details>
<summary><b>위험하지 않나?</b></summary><br>

Apple 이 제공하는 명령줄 도구를 쓰는 게 전부라 맥을 망가뜨리지 않는다. 다만 **보증은 못 한다.** 쓰는 건 본인 책임이다.

주의할 것이 하나 있다 — `뚜껑 닫아도 안 잔다` 를 켜 두면 노트북을 닫은 채 가방에 넣어도 계속 돌아간다. **열이 찬다.** 다 쓰면 되돌려 두는 게 좋다.
</details>

<details>
<summary><b>알림이 안 온다</b></summary><br>

자가 진단을 돌려 본다. 권한 상태를 찍고 알림 3종을 보낸 뒤, 알림 센터에 실제로 꽂혔는지 다시 읽어서 알려준다.

```bash
DWT_SELFTEST=1 /Applications/DadsWatchingThis.app/Contents/MacOS/DadsWatchingThis
```

`권한: 거부됨` 이 나오면 시스템 설정 ▸ 알림 에서 켠다.
</details>

## 개발

**Xcode 는 필요 없다.** Command Line Tools 만 있으면 된다.

```bash
xcode-select --install

git clone https://github.com/badeagle85/dads-watching-this.git
cd dads-watching-this
./build.sh                     # .app 빌드
./test.sh                      # 테스트 40개
./Tools/build-icon.sh          # 아이콘 다시 만들기
open build/DadsWatchingThis.app
```

직접 빌드한 앱에는 격리 딱지가 안 붙으니 `xattr` 과정이 필요 없다.

| | |
|---|---|
| 언어 | Swift (AppKit + SwiftUI) |
| 의존성 | **없음.** 아이콘도 SVG 경로를 코드에서 그린다 |
| 세션 종료 감지 | `DispatchSource` 커널 이벤트 — 폴링하지 않는다 |
| 세션 목록 조회 | 메뉴를 열 때만 |
| 테스트 | 실제로 `caffeinate` 를 띄우고 더미 프로세스를 죽여 본다. 테스트 이름 = 시나리오 케이스 번호 |

## 거들기

버그나 아이디어는 [이슈](https://github.com/badeagle85/dads-watching-this/issues)로 받는다. 양식이 준비되어 있다.

마음에 들면 [후원](https://github.com/sponsors/badeagle85)도 받는다. 다만 이 앱은 **후원과 무관하게 계속 무료**다.

## 라이선스

MIT
