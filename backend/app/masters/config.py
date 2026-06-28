"""마스터(기준정보) 설정 정의.

각 마스터를 테이블/컬럼 메타데이터로 기술하면, 범용 CRUD 라우터가
목록·검색·페이지네이션·등록·수정·삭제 엔드포인트를 자동 생성하고,
프런트엔드는 group(섹션)/help/default 등을 이용해 전용 등록 화면을 구성한다.
컬럼명/테이블명은 모두 코드에서 정의한 신뢰값이며 사용자 입력이 아니다.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional


@dataclass(frozen=True)
class Column:
    name: str
    label: str
    type: str = "text"  # text | int | number | bool | date | datetime
    required: bool = False
    editable: bool = True  # 등록/수정 가능 (False면 읽기 전용)
    in_list: bool = True  # 목록 표시
    searchable: bool = False  # 검색 대상
    group: str = "기본 정보"  # 폼 섹션
    help: str = ""  # 입력 도움말
    full_width: bool = False  # 폼에서 한 줄 전체 차지
    default: str = ""  # 신규 등록 시 기본값


@dataclass(frozen=True)
class MasterConfig:
    key: str
    label: str
    table: str
    columns: list[Column]
    subtitle: str = ""  # 탭/헤더 보조 설명
    pk: str = "id"
    tenant_col: Optional[str] = "tenant_id"
    soft_delete_col: Optional[str] = "deleted_at"
    order_by: str = "id"

    @property
    def editable_columns(self) -> list[Column]:
        return [c for c in self.columns if c.editable]

    @property
    def search_columns(self) -> list[str]:
        return [c.name for c in self.columns if c.searchable]


def _id() -> Column:
    return Column("id", "ID", "int", editable=False, in_list=True)


def _audit() -> list[Column]:
    return [
        Column("created_at", "생성일시", "datetime", editable=False, in_list=False),
        Column("updated_at", "수정일시", "datetime", editable=False, in_list=False),
    ]


MASTERS: list[MasterConfig] = [
    # 1) 거래처
    MasterConfig(
        key="partners",
        label="거래처",
        subtitle="고객사 · 화주 · 운송사",
        table="business_partners",
        columns=[
            _id(),
            Column("code", "거래처 코드", "text", required=True, searchable=True,
                   help="사내 식별 코드 (예: CUST-001)"),
            Column("name", "거래처명", "text", required=True, searchable=True),
            Column("business_no", "사업자등록번호", "text", searchable=True,
                   help="'-' 없이 입력 가능"),
            Column("is_active", "사용 여부", "bool", group="상태", default="true"),
            *_audit(),
        ],
    ),
    # 2) 배송처
    MasterConfig(
        key="locations",
        label="배송처",
        subtitle="납품처 · 하차지 · 거점",
        table="locations",
        columns=[
            _id(),
            Column("name", "배송처명", "text", required=True, searchable=True),
            Column("loc_type", "유형", "text", default="other",
                   help="shipping / delivery / warehouse / other"),
            Column("contact_phone", "연락처", "text"),
            Column("country", "국가", "text", default="KR", group="주소"),
            Column("postal_code", "우편번호", "text", group="주소"),
            Column("address", "주소", "text", required=True, searchable=True,
                   group="주소", full_width=True),
            Column("latitude", "위도", "number", group="좌표",
                   help="네이버 지도 연동용"),
            Column("longitude", "경도", "number", group="좌표"),
            *_audit(),
        ],
    ),
    # 3) 권역/노선
    MasterConfig(
        key="zones",
        label="권역/노선",
        subtitle="배송 권역",
        table="zones",
        columns=[
            _id(),
            Column("code", "권역 코드", "text", required=True, searchable=True),
            Column("name", "권역명", "text", required=True, searchable=True),
        ],
    ),
    # 4) 차량
    MasterConfig(
        key="vehicles",
        label="차량",
        subtitle="차량번호 · 톤급 · 제원",
        table="vehicles",
        tenant_col=None,
        columns=[
            _id(),
            Column("carrier_id", "운송사 ID", "int", required=True,
                   help="소속 운송사(거래처) ID"),
            Column("plate_no", "차량번호", "text", required=True, searchable=True),
            Column("vin", "차대번호(VIN)", "text", searchable=True),
            Column("equipment", "톤급/장비", "text", default="van", group="제원",
                   help="van / truck / trailer / reefer 등"),
            Column("model", "모델", "text", group="제원"),
            Column("model_year", "연식", "int", group="제원"),
            Column("capacity_kg", "적재중량(kg)", "number", group="제원"),
            Column("capacity_cbm", "적재용적(cbm)", "number", group="제원"),
            Column("status", "운행 상태", "text", default="available", group="상태",
                   help="available / in_use / maintenance 등"),
            *_audit(),
        ],
    ),
    # 5) 기사
    MasterConfig(
        key="drivers",
        label="기사",
        subtitle="기사 · 면허 · 안전",
        table="drivers",
        tenant_col=None,
        columns=[
            _id(),
            Column("carrier_id", "운송사 ID", "int", required=True,
                   help="소속 운송사(거래처) ID"),
            Column("name", "기사명", "text", required=True, searchable=True),
            Column("phone", "연락처", "text", searchable=True),
            Column("license_no", "면허번호", "text", searchable=True, group="면허"),
            Column("license_type", "면허종류", "text", group="면허"),
            Column("license_expires_on", "면허만료일", "date", group="면허"),
            Column("hazmat_certified", "위험물 운송 자격", "bool", group="면허"),
            Column("is_active", "사용 여부", "bool", group="상태", default="true"),
            *_audit(),
        ],
    ),
    # 6) 창고/거점
    MasterConfig(
        key="facilities",
        label="창고/거점",
        subtitle="창고 · 허브 · RDC",
        table="facilities",
        soft_delete_col=None,
        columns=[
            _id(),
            Column("code", "거점 코드", "text", required=True, searchable=True),
            Column("name", "거점명", "text", required=True, searchable=True),
            Column("created_at", "생성일시", "datetime", editable=False, in_list=False),
        ],
    ),
    # 7) 운임/계약
    MasterConfig(
        key="tariffs",
        label="운임/계약",
        subtitle="매출 · 매입 운임표",
        table="tariffs",
        soft_delete_col=None,
        columns=[
            _id(),
            Column("name", "운임표명", "text", required=True, searchable=True),
            Column("customer_id", "고객 ID", "int", help="대상 고객(거래처) ID"),
            Column("carrier_id", "운송사 ID", "int", help="대상 운송사(거래처) ID"),
            Column("currency", "통화", "text", default="KRW", group="적용 조건"),
            Column("valid_from", "유효 시작일", "date", required=True, group="적용 조건"),
            Column("valid_to", "유효 종료일", "date", group="적용 조건",
                   help="비우면 무기한"),
            *_audit(),
        ],
    ),
    # 8) 사용자
    MasterConfig(
        key="users",
        label="사용자",
        subtitle="시스템 사용자",
        table="users",
        columns=[
            _id(),
            Column("email", "이메일", "text", required=True, searchable=True),
            Column("full_name", "이름", "text", required=True, searchable=True),
            Column("employee_no", "사번", "text", searchable=True),
            Column("phone", "연락처", "text", group="연락 · 직책"),
            Column("job_title", "직책", "text", group="연락 · 직책"),
            Column("is_active", "사용 여부", "bool", group="상태", default="true"),
            *_audit(),
        ],
    ),
    # 9) 역할
    MasterConfig(
        key="roles",
        label="역할",
        subtitle="권한 역할",
        table="roles",
        tenant_col=None,
        soft_delete_col=None,
        columns=[
            _id(),
            Column("code", "역할 코드", "text", required=True, searchable=True),
            Column("name", "역할명", "text", required=True, searchable=True),
            Column("description", "설명", "text", full_width=True),
            Column("is_system", "시스템 역할", "bool", editable=False, group="상태"),
        ],
    ),
    # 10) 세금코드
    MasterConfig(
        key="tax_codes",
        label="세금코드",
        subtitle="공통코드",
        table="tax_codes",
        soft_delete_col=None,
        columns=[
            _id(),
            Column("code", "코드", "text", required=True, searchable=True),
            Column("name", "명칭", "text", required=True, searchable=True),
            Column("tax_type", "세금유형", "text", required=True,
                   help="VAT / WHT 등"),
            Column("rate", "세율(%)", "number", required=True, group="세율 · 적용"),
            Column("country", "국가", "text", default="KR", group="세율 · 적용"),
            Column("effective_from", "적용 시작일", "date", group="세율 · 적용"),
            Column("effective_to", "적용 종료일", "date", group="세율 · 적용"),
            Column("is_active", "사용 여부", "bool", default="true", group="상태"),
            Column("created_at", "생성일시", "datetime", editable=False, in_list=False),
        ],
    ),
    # 11) 회계코드
    MasterConfig(
        key="gl_codes",
        label="회계코드",
        subtitle="공통코드",
        table="gl_codes",
        columns=[
            _id(),
            Column("code", "코드", "text", required=True, searchable=True),
            Column("name", "명칭", "text", required=True, searchable=True),
        ],
    ),
    # 12) 부가요금유형
    MasterConfig(
        key="accessorial_types",
        label="부가요금유형",
        subtitle="공통코드",
        table="accessorial_types",
        columns=[
            _id(),
            Column("code", "코드", "text", required=True, searchable=True),
            Column("name", "명칭", "text", required=True, searchable=True),
            Column("default_rate", "기본 요율", "number"),
        ],
    ),
]

MASTERS_BY_KEY: dict[str, MasterConfig] = {m.key: m for m in MASTERS}
