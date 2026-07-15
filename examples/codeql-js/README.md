# CodeQL 문법 학습·시연용 예제 (JavaScript)

CodeQL 쿼리 문법을 이해하기 위한 **예제 모음**입니다.
쉬운 것부터 실제 보안 쿼리(taint tracking)까지 단계적으로 구성했습니다.

> ⚠️ **이 폴더는 실제 스캔에 포함되지 않습니다.**
> 데모 앱은 파이썬이고(`codeql.yml` → `languages: python`), 실제 커스텀 쿼리는
> `.github/codeql/custom-queries/`(파이썬)만 돌아갑니다. 이 예제들은 `custom-queries/`
> **밖**에 있고 config-file 이 참조하지 않으므로 스캔에 딸려가지 않습니다. **보여주기·학습 전용.**

## 쿼리 골격

```
from <타입> <변수>   -- 무엇을 훑을지 선언
where <조건>          -- 필터
select <위치>, <메시지> -- alert로 출력
```

## 예제 목록 (난이도 순)

| 파일 | 배우는 문법 | 한 줄 요약 |
|---|---|---|
| `1-eval-basic.ql` | `from/where/select`, `.getCalleeName()` | eval 호출 찾기 |
| `2-dangerous-calls.ql` | `or`, 집합 리터럴 `= [ ... ]`, 문자열 `+` | 위험 함수 여러 개 |
| `3-hardcoded-secret.ql` | 여러 타입 조인, 캐스팅 `.(T)`, `regexpMatch` | 시크릿 이름+문자열 |
| `4-taint-eval.ql` | `DataFlow::Node`, `instanceof`, `exists`, `TaintTracking::localTaint`, `$@` | 입력이 eval까지 흐르는 진짜 인젝션 |

## 핵심 차이: 존재 확인 vs 흐름 추적

- **예제 1~3**: "그런 코드가 **있냐**"만 확인 → 간단하지만 오탐 가능(`eval("1+1")`도 잡힘).
- **예제 4**: "신뢰 못 할 입력이 위험 지점까지 **실제로 흐르냐**"를 추적 → 진짜 위험만 정밀 탐지.
  이 source→sink 흐름 추적이 CodeQL이 단순 grep과 다른 이유입니다.

## 문법 치트시트

| 요소 | 뜻 |
|---|---|
| `from T x` | T 타입을 x로 훑기 |
| `and` / `or` | 조건 결합 |
| `.(Type)` | 타입 캐스팅 |
| `= [a, b, c]` | 집합 중 하나와 같으면 참 |
| `instanceof` | 타입 검사 |
| `exists(x \| ...)` | 조건을 만족하는 x가 존재하는가 |
| `::` | 모듈 경로(네임스페이스) |
| `$@` | select에서 뒤 인자로 치환되는 링크 플레이스홀더 |

## 실제로 돌려보려면

JS 소스가 있는 repo에서 `codeql.yml` 의 `languages: python` → `javascript` 로 바꾸고,
`codeql-config.yml` 이 이 폴더를 가리키게 하면 됩니다. (지금 데모는 파이썬이라 그대로 두세요.)

## 더 배우기 (공식 리소스)

문법·사용법은 **공식 문서가 정답**입니다. 순서대로 보세요.

1. **문서 허브** — 모든 게 여기서 갈라짐
   <https://codeql.github.com/docs/>
2. **JS 언어 가이드** — `from/where/select`, 클래스, predicate, 데이터플로우, taint tracking을 예제와 함께
   <https://codeql.github.com/docs/codeql-language-guides/codeql-for-javascript/>
3. **JS 표준 라이브러리 레퍼런스** — `CallExpr`, `getCalleeName()`, `DataFlow`, `TaintTracking` 등 원출처 검색
   <https://codeql.github.com/codeql-standard-libraries/javascript/>
4. **VS Code CodeQL 확장** — 로컬에서 쿼리 실행·자동완성 (읽기만 말고 직접 돌려봐야 늚)
   <https://docs.github.com/en/code-security/codeql-for-vs-code>
5. **학습 코스 / variant analysis** — 문제 풀며 익히기
   <https://codeql.github.com/docs/writing-codeql-queries/codeql-training-and-variant-analysis/>

**추천 경로:** 2번으로 개념 잡고 → 4번(VS Code)에서 위 4개 `.ql`을 직접 실행 → 막히는 클래스는 3번에서 검색.
