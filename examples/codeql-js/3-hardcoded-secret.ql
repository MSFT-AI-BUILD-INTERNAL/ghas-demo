/**
 * @name [예제3] 하드코딩된 시크릿 의심 (여러 타입 조인 + 캐스팅 + 정규식)
 * @description "시크릿스러운 변수 이름 + 문자열 리터럴" 조합을 탐지.
 * @kind problem
 * @problem.severity warning
 * @id js/examples/3-hardcoded-secret
 * @tags examples
 */

import javascript

from VariableDeclarator v, StringLiteral s // 두 타입을 동시에 훑는다(테이블 조인처럼)
where
  v.getInit() = s and // 변수의 초기값이 그 문자열이고
  // 변수 이름이 password/secret/token/apikey 를 포함하면 (대소문자 무시)
  v.getBindingPattern().(Identifier).getName().regexpMatch("(?i).*(password|secret|token|apikey).*")
select v, "하드코딩된 시크릿 의심: " + s.getValue()
