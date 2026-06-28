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
    # 13) 부서
    MasterConfig(
        key="departments",
        label="부서",
        subtitle="조직 · 팀",
        table="departments",
        columns=[
            _id(),
            Column("code", "부서 코드", "text", required=True, searchable=True),
            Column("name", "부서명", "text", required=True, searchable=True),
            Column("parent_id", "상위 부서 ID", "int",
                   help="상위 부서가 있으면 입력"),
        ],
    ),
    # 14) 통화
    MasterConfig(
        key="currencies",
        label="통화",
        subtitle="통화 · 환율",
        table="currencies",
        pk="code",
        tenant_col=None,
        soft_delete_col=None,
        columns=[
            Column("code", "통화 코드", "text", editable=False, required=True, searchable=True,
                   help="ISO 4217 코드 (예: KRW, USD)"),
            Column("name", "통화명", "text", required=True, searchable=True),
            Column("minor_unit", "소수점 자릿수", "int", default="2"),
        ],
    ),
    # 15) 노선/거리
    MasterConfig(
        key="lanes",
        label="노선/거리",
        subtitle="운송 경로 · 거리",
        table="lanes",
        columns=[
            _id(),
            Column("origin_zone_id", "출발 권역 ID", "int", required=True,
                   help="출발지 권역"),
            Column("dest_zone_id", "도착 권역 ID", "int", required=True,
                   help="도착지 권역"),
            Column("distance_km", "거리(km)", "number", group="기본 정보"),
            Column("transit_hours", "소요시간(시간)", "number", group="기본 정보"),
        ],
    ),
    # 16) 거래처 연락처
    MasterConfig(
        key="partner_contacts",
        label="거래처 연락처",
        subtitle="거래처 담당자",
        table="partner_contacts",
        soft_delete_col=None,
        columns=[
            _id(),
            Column("partner_id", "거래처 ID", "int", required=True,
                   help="거래처 ID"),
            Column("name", "담당자명", "text", required=True, searchable=True),
            Column("role", "직책", "text", group="정보"),
            Column("email", "이메일", "text", group="정보"),
            Column("phone", "연락처", "text", group="정보"),
            Column("is_primary", "주담당자", "bool", group="상태", default="false"),
        ],
    ),
    # 17) 운송사 역량
    MasterConfig(
        key="carrier_capabilities",
        label="운송사 역량",
        subtitle="운송사 · 장비 · 구역",
        table="carrier_capabilities",
        soft_delete_col=None,
        columns=[
            _id(),
            Column("carrier_id", "운송사 ID", "int", required=True),
            Column("equipment", "장비 유형", "text", required=True, searchable=True,
                   help="van / truck / trailer / reefer 등"),
            Column("zone_id", "서비스 권역 ID", "int",
                   help="특정 권역에만 서비스하면 입력"),
            Column("can_hazmat", "위험물 운송 가능", "bool", default="false"),
            Column("can_reefer", "냉동 운송 가능", "bool", default="false"),
            Column("max_weight_kg", "최대 적재중량(kg)", "number"),
        ],
    ),
    # 18) 운송사 인증
    MasterConfig(
        key="carrier_certifications",
        label="운송사 인증",
        subtitle="자격증 · 인증 · 면허",
        table="carrier_certifications",
        soft_delete_col=None,
        columns=[
            _id(),
            Column("carrier_id", "운송사 ID", "int", required=True),
            Column("cert_type", "인증 유형", "text", required=True, searchable=True,
                   help="ISO / HAZMAT / REEFER 등"),
            Column("cert_no", "인증 번호", "text", searchable=True),
            Column("issuer", "발급처", "text"),
            Column("issued_date", "발급일", "date"),
            Column("expires_date", "만료일", "date", required=True),
            Column("is_active", "사용 여부", "bool", default="true", group="상태"),
        ],
    ),
    # 19) 환율
    MasterConfig(
        key="exchange_rates",
        label="환율",
        subtitle="통화 · 환전",
        table="exchange_rates",
        pk="id",
        tenant_col=None,
        soft_delete_col=None,
        columns=[
            Column("id", "ID", "int", editable=False),
            Column("base_currency", "기본 통화", "text", required=True, searchable=True,
                   help="ISO 코드 (예: KRW)"),
            Column("quote_currency", "상대 통화", "text", required=True, searchable=True,
                   help="ISO 코드 (예: USD)"),
            Column("rate", "환율", "number", required=True),
            Column("effective_date", "적용일", "date", required=True),
        ],
    ),
    # 20) 유가할증료 기준
    MasterConfig(
        key="fuel_surcharge_brackets",
        label="유가할증료 기준",
        subtitle="유가 연동",
        table="fuel_surcharge_brackets",
        columns=[
            _id(),
            Column("price_from", "유가 범위(시작)", "number", required=True,
                   help="리터당 가격"),
            Column("price_to", "유가 범위(종료)", "number",
                   help="비우면 상한 없음"),
            Column("surcharge_pct", "할증율(%)", "number", required=True),
        ],
    ),
    # 21) KPI 정의
    MasterConfig(
        key="kpi_definitions",
        label="KPI 정의",
        subtitle="성과 지표",
        table="kpi_definitions",
        columns=[
            _id(),
            Column("code", "KPI 코드", "text", required=True, searchable=True),
            Column("name", "KPI명", "text", required=True, searchable=True),
            Column("category", "분류", "text", required=True,
                   help="운전 / 품질 / 비용 등"),
            Column("unit", "단위", "text", required=True,
                   help="시간 / 건 / % 등"),
            Column("aggregation", "집계 방식", "text", default="AVG",
                   help="AVG / SUM / MAX / MIN"),
            Column("higher_is_better", "높을수록 좋음", "bool", default="true"),
            Column("description", "설명", "text", group="상세", full_width=True),
        ],
    ),
    # 22) 번호 시퀀스
    MasterConfig(
        key="number_sequences",
        label="번호 시퀀스",
        subtitle="번호 채번",
        table="number_sequences",
        pk="seq_type",
        tenant_col="tenant_id",
        soft_delete_col=None,
        columns=[
            Column("seq_type", "시퀀스 타입", "text", editable=False, required=True,
                   searchable=True, help="ORDER / SHIPMENT / INVOICE 등"),
            Column("prefix", "접두사", "text", required=True,
                   help="예: ORD-, SHP-, INV-"),
            Column("last_value", "마지막 값", "int", required=True, default="0"),
        ],
    ),
]

MASTERS_BY_KEY: dict[str, MasterConfig] = {m.key: m for m in MASTERS}
