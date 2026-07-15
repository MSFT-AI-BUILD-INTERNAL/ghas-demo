/**
 * @name [예제2] 동적 코드 실행 함수들 탐지 (or / 집합 / 문자열 결합)
 * @description eval 외에 new Function(...), execScript 등 여러 위험 함수를 한 번에.
 * @kind problem
 * @problem.severity warning
 * @id js/examples/2-dangerous-calls
 * @tags examples
 */

import javascript

from CallExpr call
where
  // 방법 A) or 로 나열
  //   call.getCalleeName() = "eval" or
  //   call.getCalleeName() = "Function" or
  //   call.getCalleeName() = "execScript"
  // 방법 B) 집합 리터럴 = [ ... ] 로 짧게 (아래가 위 셋과 동일)
  call.getCalleeName() = ["eval", "Function", "execScript"]
select call, "동적 코드 실행 위험: " + call.getCalleeName() + " 사용"
