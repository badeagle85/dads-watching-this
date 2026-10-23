<div align="center">

<img src="docs/images/app-icon.png" width="128" alt="아빠안잔다">

# 아빠안잔다

**Dad's Watching This!**

AI 세션이 도는 동안 맥을 안 재우는 macOS 메뉴바 앱<br>
지금 지키고 있는지를 **아이콘 모양만 보고** 안다

<img src="docs/images/state-sleeping.png" width="56" alt="잔다">
<img src="docs/images/state-awake.png" width="56" alt="안 잔다">
<img src="docs/images/state-session.png" width="56" alt="세션 지키는 중">
<img src="docs/images/state-lid.png" width="56" alt="뚜껑 닫아도 안 잔다">

</div>

---

> 자리를 비우면 세션이 살아 있는지 알 수가 없다. 돌아와 보면 끊겨 있고, 언제 끊겼는지도 모른다.
> 그래서 만들었다.

## 메뉴

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

## 무엇이 다른가

`caffeinate` 를 감싸는 앱은 이미 여럿 있다. 이 앱은 두 가지를 더 한다.

| | |
|---|---|
| **상태가 형태로 보인다** | 메뉴바 아이콘은 색을 못 쓴다(template image). 그래서 윤곽·파동·채움 **세 가지 모양**으로 상태를 나눴다 |
| **세션을 지목한다** | "30분" 이 아니라 **"이 세션이 끝날 때까지"**. 고른 세션이 끝나면 저절로 풀린다 |

## 아이콘 읽는 법

| | 모양 | 뜻 |
|:---:|---|---|
| <img src="docs/images/state-sleeping.png" width="40"> | 윤곽 | **잔다** — 아무것도 안 걸렸다 |
| <img src="docs/images/state-awake.png" width="40"> | 윤곽 + 파동 | **안 잔다** — 깨워 두는 중 |
| <img src="docs/images/state-session.png" width="40"> | 채움 + 파동 | **세션 지키는 중** — 그 세션이 끝나면 풀린다 |
| <img src="docs/images/state-lid.png" width="40"> | **테두리** | 뚜껑 닫힘 시스템 설정이 켜져 있다 (앱과 별개) |

테두리는 세 모양 어디에나 붙는다. 앱 상태와 시스템 설정은 서로 다른 축이다.

아이콘 옆 숫자는 켜 둔 지 얼마나 됐는지다. `숨김 / 시:분 / 시:분:초` 중에 고른다.

## 뚜껑을 닫으면

**`caffeinate` 로는 뚜껑 닫힘(Clamshell Sleep)을 못 막는다.** 실측으로 확인했다 — 충전기를 꽂고 외부 모니터를 빼도 뚜껑을 닫으면 5초 만에 잠든다.

막는 방법은 하나뿐이고 시스템 설정이다.

```bash
sudo pmset -a disablesleep 1   # 켜기
sudo pmset -a disablesleep 0   # 되돌리기
```

앱에서 `뚜껑 닫아도 안 잔다…` 를 누르면 이 명령을 대신 실행한다. **암호는 macOS 가 직접 받고 앱은 보지 못한다.** 이 설정은 앱을 꺼도, 재부팅해도 남기 때문에 켜져 있는 동안 아이콘에 테두리가 붙는다.

## 설치

```bash
brew tap badeagle85/tap
brew trust badeagle85/tap
brew install --cask dads-watching-this
xattr -dr com.apple.quarantine /Applications/DadsWatchingThis.app
```

> [!IMPORTANT]
> **네 번째 줄을 앱을 열기 전에 실행해야 한다.**
> 격리 딱지가 붙은 채로 열면 macOS 가 "열 수 없다" 며 **앱을 지우라고 권하고, 거기서 확인을 누르면 앱이 사라진다.**
> 그때는 `brew reinstall --cask dads-watching-this` 로 다시 받은 뒤 위 순서대로 하면 된다.

왜 이런 과정이 필요한가 — 이 앱은 **Apple 공증을 받지 않았다.** 공증에는 Apple Developer Program 연 $99 가 든다. 공증 대신 **소스를 전부 공개**하는 쪽을 택했다. 위 명령이 하는 일은 "이 앱은 인터넷에서 받은 것"이라는 표시를 떼는 것뿐이다.

`brew trust` 는 Homebrew 가 공식 저장소 밖의 설치 정의를 쓰기 전에 요구하는 확인이다.

### 직접 빌드하기

**Xcode 는 필요 없다.** Command Line Tools 만 있으면 된다.

```bash
xcode-select --install

git clone https://github.com/badeagle85/dads-watching-this.git
cd dads-watching-this
./build.sh
open build/DadsWatchingThis.app
```

직접 빌드한 앱에는 격리 딱지가 안 붙으니 위 과정이 필요 없다.

## 테스트

```bash
./test.sh
```

실제로 `caffeinate` 를 띄우고 더미 프로세스를 죽여 보는 식으로 돈다. 테스트 이름은 시나리오 문서의 케이스 번호다.

알림이 안 온다면 자가 진단을 돌려 본다. 권한 상태를 찍고 알림 3종을 보낸 뒤, 알림 센터에 실제로 꽂혔는지 다시 읽어서 알려준다.

```bash
DWT_SELFTEST=1 /Applications/DadsWatchingThis.app/Contents/MacOS/DadsWatchingThis
```

## 만든 방식

| | |
|---|---|
| 언어 | Swift (AppKit + SwiftUI) |
| 의존성 | **없음.** 아이콘도 SVG 경로를 코드에서 그린다 |
| 유지 방식 | `/usr/bin/caffeinate -i -w <앱 PID>` 자식 프로세스 하나 |
| 세션 종료 감지 | `DispatchSource` 커널 이벤트 — 폴링하지 않는다 |
| 요구 사항 | macOS 14 이상 |

앱이 죽으면 `-w` 때문에 `caffeinate` 도 같이 죽는다. 좀비가 안 남는다.

## 라이선스

MIT
