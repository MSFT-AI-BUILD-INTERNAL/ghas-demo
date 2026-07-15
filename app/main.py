"""
데모용 Flask 앱 — 일부러 취약점을 심어둔 코드입니다.
GHAS가 각 취약점을 어떻게 잡는지 시연하기 위한 목적입니다.

심어둔 취약점:
  1) SQL Injection        -> CodeQL(Code Scanning)이 탐지
  2) 하드코딩된 시크릿      -> Secret Scanning / Push Protection이 탐지
  3) 취약한 의존성          -> requirements.txt + Dependabot이 탐지
  4) 사내 금지 함수(eval)   -> 커스텀 CodeQL 쿼리가 탐지
  5) 비구조화 시크릿        -> Copilot 기반(AI) generic secret 탐지가 탐지
"""
import sqlite3
from flask import Flask, request

app = Flask(__name__)

# [취약점 2] 하드코딩된 시크릿 (데모용 가짜 값 — 실제 키 아님)
# Secret Scanning이 이 Azure Storage 연결 문자열을 탐지해 alert를 생성합니다(데모 F).
# Push Protection이 켜져 있으면 이런 값이 든 새 커밋의 push도 차단됩니다(데모 A).
AZURE_STORAGE_CONNECTION_STRING = "DefaultEndpointsProtocol=https;AccountName=demostorage;AccountKey=wBHahhaeRjx0uAvnm4WCEvW5YxPz6hUU9Gget93V98yg8yQDazFgcWyDBWQvFddmLnQFDdvw1yh/U2LPP8+qYQ==;EndpointSuffix=core.windows.net"  # noqa
SLACK_TOKEN = "xoxb-1234567890-DEMO-not-a-real-token"  # noqa
# [취약점 4] 사내 커스텀 패턴 데모용 토큰 (COMP-xxxx 형식)
INTERNAL_TOKEN = "COMP-ABCD1234ABCD1234ABCD1234ABCD1234"  # noqa

# [취약점 5] 비구조화 시크릿 — 고정 패턴이 없어 정규식으론 못 잡습니다.
# Copilot 기반(AI) Secret Scanning의 generic secret 탐지가 이런 값을 잡습니다.
# (데모용 가짜 값)
db_connection_string = "postgres://demo_admin:S3cur3-P@ssw0rd-2024@internal-db.demo.local:5432/prod"  # noqa


@app.route("/user")
def get_user():
    user_id = request.args.get("id", "")
    conn = sqlite3.connect("demo.db")
    cur = conn.cursor()
    # [취약점 1] SQL Injection — 사용자 입력을 문자열로 직접 이어붙임
    query = "SELECT * FROM users WHERE id = '" + user_id + "'"
    cur.execute(query)
    return {"rows": cur.fetchall()}


@app.route("/calc")
def calc():
    expr = request.args.get("expr", "0")
    # [취약점 4] eval 사용 — 사내 정책상 금지, 커스텀 CodeQL 쿼리가 탐지
    return {"result": eval(expr)}  # noqa: S307


if __name__ == "__main__":
    app.run(debug=True)
