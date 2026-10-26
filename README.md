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

<sub>테두리는 세 모양 어디에나 붙는다 — 앱 상태와 시스템 설정은 다른 축이다</sub>

</div>

---

Claude Code 를 돌려 놓고 자리를 비우면 **세션이 살아 있는지 알 수가 없다.** 돌아와 보면 끊겨 있고, 언제 왜 끊겼는지도 모른다. 그래서 만들었다.

## 설치

```bash
brew tap badeagle85/tap
brew trust badeagle85/tap
brew install --cask dads-watching-this
xattr -dr com.apple.quarantine /Applications/DadsWatchingThis.app
```

> [!IMPORTANT]
> **네 번째 줄을 앱을 열기 전에 실행해야 한다.** 격리 딱지가 붙은 채로 열면 macOS 가 앱을 지우라고 권하고, 확인을 누르면 앱이 사라진다. 그때는 `brew reinstall --cask dads-watching-this` 로 다시 받는다.

## 메뉴

```
잔다
──────────────────────
화면 끄고 지키기                  자리 비울 때 한 번으로. 유지를 켜고 화면을 끈다
──────────────────────
언제까지 안 자나
✓ 끌 때까지
  30분 / 1시간 / 2시간
  세션이 끝날 때까지      ▸      makestar · 2시간
                               commerce-web · 18분
──────────────────────
✓ 배터리 20% 밑이면 잔다
✓ 뚜껑 닫아도 안 잔다…            시스템 설정. 암호는 macOS 가 받는다
  로그인할 때 자동 실행
  메뉴바 경과 시간        ▸      숨김 / 시:분 / 시:분:초
──────────────────────
  이제 잔다
  아이콘 읽는 법…
  종료                ⌘Q
```

전역 단축키 **⌥⌘L** 로 어느 앱에서든 켜고 끈다.

## 기능

- [x] 메뉴바에서 상태 확인 — 3가지 모양 × 테두리
- [x] 끝나는 조건 선택 — 끌 때까지 / 30분 / 1시간 / 2시간 / **세션이 끝날 때까지**
- [x] Claude Code 세션 목록에서 지목 (최근 12시간, 폴더명으로 구분)
- [x] 화면 끄고 지키기
- [x] 뚜껑 닫힘 시스템 설정 읽기·쓰기
- [x] 끊김 이력 — 자리 비운 사이 잠들었으면 시각과 사유
- [x] 알림 3종 — 세션 종료 · 충전기 분리 · 배터리 해제
- [x] 배터리 20% 자동 해제 · 로그인 자동 실행 · 전역 단축키
- [ ] 영어 (지금은 한국어만)
- [ ] 자동 업데이트
- [ ] 고른 세션이 끝나면 다른 세션으로 이관
- [ ] Codex·Cursor 등 다른 에이전트 연동

## 자주 묻는 것

<details>
<summary><b>비슷한 앱이 이미 있지 않나?</b></summary><br>

`caffeinate` 를 감싸는 앱은 여럿 있지만 전부 켜짐/꺼짐 두 단계다. 이 앱은 **상태를 형태로 보여주고**(색을 못 쓰는 메뉴바에서 윤곽·파동·채움), **세션을 지목**해서 그게 끝날 때 푼다.
</details>

<details>
<summary><b>어떻게 동작하나?</b></summary><br>

macOS 기본 명령 `caffeinate` 를 감싼다.

```
/usr/bin/caffeinate -i -w <앱 PID>
```

`-i` 는 시스템 잠만 막는다 — 자리를 비우는 게 전제라 화면은 평소대로 꺼진다. `-w <앱 PID>` 덕분에 **앱이 죽으면 `caffeinate` 도 같이 죽어** 좀비가 안 남는다.
</details>

<details>
<summary><b>뚜껑을 닫아도 되나?</b></summary><br>

**`caffeinate` 로는 뚜껑 닫힘을 못 막는다.** 실측으로 확인했다 — 충전기를 꽂고 외부 모니터를 빼도 5초 만에 잠든다. 막는 건 시스템 설정 하나뿐이다.

```bash
sudo pmset -a disablesleep 1   # 켜기
sudo pmset -a disablesleep 0   # 되돌리기
```

메뉴의 `뚜껑 닫아도 안 잔다…` 가 이걸 대신 실행한다. 암호는 macOS 가 직접 받고 앱은 보지 못한다. 이 설정은 앱을 꺼도 재부팅해도 남아서, 켜져 있는 동안 아이콘에 테두리가 붙는다. **가방 안에서도 계속 돌아 열이 차니** 다 쓰면 되돌려 두는 게 좋다.
</details>

<details>
<summary><b>설치할 때 왜 명령을 네 줄이나 치나?</b></summary><br>

**Apple 공증을 받지 않았다.** 연 $99 가 드는데, 사용자가 생기기 전에 연회비부터 내는 건 순서가 거꾸로라 보고 **소스 공개**를 택했다. `xattr` 은 "인터넷에서 받았다"는 표시를 떼는 것뿐이다. Homebrew 가 `--no-quarantine` 으로 해 주던 일인데 **7.0 에서 그 옵션이 제거됐다.**
</details>

<details>
<summary><b>알림이 안 온다</b></summary><br>

자가 진단을 돌린다. 권한 상태를 찍고 알림 3종을 보낸 뒤 알림 센터에 실제로 꽂혔는지 다시 읽어서 알려준다.

```bash
DWT_SELFTEST=1 /Applications/DadsWatchingThis.app/Contents/MacOS/DadsWatchingThis
```
</details>

## 직접 빌드하기

**Xcode 가 필요 없다.** Command Line Tools 만 있으면 된다.

```bash
xcode-select --install
git clone https://github.com/badeagle85/dads-watching-this.git
cd dads-watching-this
./build.sh && open build/DadsWatchingThis.app
```

`./test.sh` 로 테스트 40개, `./Tools/build-icon.sh` 로 아이콘을 다시 만든다. 직접 빌드한 앱에는 격리 딱지가 안 붙어 `xattr` 이 필요 없다.

의존성이 **없다.** 아이콘도 SVG 경로를 코드에서 그리고, 세션 종료는 `DispatchSource` 커널 이벤트로 받아 폴링하지 않는다.

## 거들기

버그와 아이디어는 [이슈](https://github.com/badeagle85/dads-watching-this/issues)로. [후원](https://github.com/sponsors/badeagle85)도 받지만 이 앱은 후원과 무관하게 계속 무료다.

## 라이선스

MIT
