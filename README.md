# game-project

여러 게임을 한곳에 모아둔 폴더입니다.
게임 하나가 곧 하위 폴더 하나이며, 각 게임은 서로 독립적으로 빌드하고 실행합니다.

## 게임 목록

| 게임 | 폴더 | 플랫폼 / 기술 | 실행 |
|---|---|---|---|
| 세계마뷸 (World Marble) | [segyemabyul/](segyemabyul/) | Windows · C# WinForms (.NET Framework 4.x) | `segyemabyul\dist\segyemabyul.exe` |
| 빠칭코 — 불멸의 이순신 | [pachinko/](pachinko/) | Windows · C# WinForms (.NET Framework 4.x) | `pachinko\dist\pachinko.exe` |
| 〃 (Godot 이식) | [pachinko-godot/](pachinko-godot/) | Windows · Godot 4 (GDScript) | `pachinko-godot\dist\pachinko.exe` |
| 좀비디펜스 (Zombie Defense) | [zombie-defense/](zombie-defense/) | Windows · Godot 4 (GDScript) | `zombie-defense\dist\zombie-defense.exe` |
| 랜덤 디펜스 (Random Defense) | [random-defense/](random-defense/) | Windows · Godot 4 (GDScript, 로우폴리 3D) | `random-defense\dist\random-defense.exe` |

## 폴더 규칙

```
game-project/
├─ README.md          이 파일 (게임 목록)
├─ CLAUDE.md          작업 규칙
└─ <게임이름>/         게임 하나 = 폴더 하나
   ├─ README.md       그 게임의 소개 · 조작 · 규칙 · 빌드법
   ├─ src/            소스
   ├─ dist/           빌드 결과물 (실행 파일 등)
   └─ build.bat       빌드 스크립트
```

- 새 게임은 항상 **루트 바로 아래 새 폴더**로 추가합니다. 기존 게임 폴더 안에 넣지 않습니다.
- 게임끼리 코드를 공유하지 않습니다. 각 폴더만 복사해도 그 게임이 그대로 동작해야 합니다.
- 폴더 이름은 소문자·하이픈(`segyemabyul`, `tetris`, `go-stop`)을 씁니다.
- 게임마다 **자기 README와 빌드 스크립트를 반드시** 둡니다. 새 게임을 추가하면 위 목록에 한 줄 더합니다.
- 기술 스택은 게임마다 자유롭게 고릅니다. 통일할 필요 없습니다.

## 빌드

각 게임 폴더에서 그 게임의 빌드 스크립트를 실행합니다.

```
cd segyemabyul
build.bat
```

세계마뷸은 Visual Studio나 .NET SDK 없이 **Windows에 내장된 C# 컴파일러**만으로 빌드되며,
결과물은 DLL·이미지·설정 파일이 필요 없는 **단일 exe** 입니다.
