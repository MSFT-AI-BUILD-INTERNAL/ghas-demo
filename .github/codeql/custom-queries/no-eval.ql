/**
 * @name eval 사용 금지 (사내 정책)
 * @description 사내 보안 정책상 eval() 호출을 금지합니다. 코드 인젝션 위험이 있습니다.
 * @kind problem
 * @problem.severity error
 * @security-severity 8.0
 * @precision high
 * @id py/company/no-eval
 * @tags security
 *       company-policy
 */

import python

from Call call
where call.getFunc().(Name).getId() = "eval"
select call, "사내 정책 위반: eval() 사용이 감지되었습니다. 안전한 대체 방법을 사용하세요."
