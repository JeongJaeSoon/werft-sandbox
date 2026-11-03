# werft-sandbox

agent-platform의 GitHub 연동(clone, 승인 push, PR 생성)을 점검하기 위한 테스트 저장소입니다.

## 구성

| 경로 | 설명 |
| --- | --- |
| `notes/a.txt`, `notes/b.txt` | 변경 사항을 만들어 push와 PR 흐름을 확인하는 데 쓰는 샘플 파일 |
| `.github/workflows/sandbox-dispatch.yml` | `workflow_dispatch`로 수동 실행하는 점검용 워크플로 |
| `.github/workflows/sandbox-other.yml` | 위와 같은 방식으로 실행하는 두 번째 점검용 워크플로 |

두 워크플로는 `permissions: {}`로 권한 없이 실행되며, 각각 메시지를 출력하는 `echo` 잡 하나만 갖습니다.

## 용도

- 에이전트가 저장소를 clone하고 브랜치에서 작업할 수 있는지 확인
- 승인이 필요한 push 요청이 정상적으로 처리되는지 확인
- push된 브랜치에서 PR이 만들어지는지 확인
- 워크플로를 수동으로 실행해 동작을 실측

실제 서비스 코드는 없으며, 연동 점검 외의 용도로 쓰지 않습니다.
