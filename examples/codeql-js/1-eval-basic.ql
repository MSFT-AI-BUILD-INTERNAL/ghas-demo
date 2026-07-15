/**
 * @name [예제1] eval() 사용 탐지 (가장 기본)
 * @description CodeQL 문법의 뼈대: from(무엇을) → where(조건) → select(출력).
 * @kind problem
 * @problem.severity warning
 * @id js/examples/1-eval-basic
 * @tags examples
 */

import javascript // JS 라이브러리 로드(문법 타입·메서드 제공)

from CallExpr call // "함수 호출(CallExpr)"을 call 이라 부르며 전부 훑는다
where call.getCalleeName() = "eval" // 그중 호출 이름이 "eval"인 것만
select call, "eval() 사용 금지" // 걸린 위치 + 메시지 출력
