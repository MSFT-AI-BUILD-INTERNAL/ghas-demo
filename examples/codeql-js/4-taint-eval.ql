/**
 * @name [예제4] 사용자 입력이 eval로 흐름 (taint tracking, 진짜 보안 쿼리의 핵심)
 * @description 신뢰 못 할 입력(source)이 eval의 인자(sink)까지 실제로 전파되는 경우만 탐지.
 *              예제1~3(존재만 확인)과 달리, "실제 흐름"을 추적해 오탐을 줄인다.
 * @kind problem
 * @problem.severity error
 * @security-severity 9.0
 * @id js/examples/4-taint-eval
 * @tags examples security
 */

import javascript
import semmle.javascript.dataflow.TaintTracking // 흐름 추적 라이브러리

from DataFlow::Node source, DataFlow::Node sink
where
  // source: 신뢰 못 할 외부 입력(req.query, location.search 등을 라이브러리가 미리 정의)
  source instanceof RemoteFlowSource and
  // sink: eval 호출의 첫 번째 인자 자리
  exists(CallExpr call |
    call.getCalleeName() = "eval" and
    sink.asExpr() = call.getArgument(0)
  ) and
  // source의 오염된 값이 sink까지 실제로 전파되면 참
  TaintTracking::localTaint(source, sink)
// $@ 는 플레이스홀더 → 뒤의 source,"입력 지점" 으로 치환돼 입력 위치로 이동 링크가 됨
select sink, "사용자 입력이 eval로 흘러감(코드 인젝션): $@", source, "입력 지점"
