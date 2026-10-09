#!/usr/bin/env python3
"""The SAP Gateway Service Builder (SEGW) as a code generator, in Python.

Run:  python3 segw_generation.py

A SEGW project holds a data model and nothing else: entity types with their
properties and keys, entity sets, associations with navigation properties,
function imports. Everything else is derived from it: the names of the four
classes and the two registered objects, the $metadata document the service
answers with, and one method per entity set and operation in the data
provider class. Your code goes into the two _EXT subclasses only, because
the next generation rewrites the other two.

This program does those derivations for a small customer model over the
business partner and its identification numbers (tables BUT000 and BUT0ID),
checks the delivered project names against ABAP's 30-character limit, prints
the $metadata the model turns into, sends a handful of OData requests to the
methods they reach, and shows what a regeneration keeps and what it orphans.

Stdlib only. It simulates the generator's rules as the page states them; it
is not SAP, and the page says how sure each rule is and where to check it.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from urllib.parse import parse_qsl

MAX_ABAP_NAME = 30      # class names and method names in ABAP: 30 characters


def section(title: str) -> None:
    print()
    print(title)
    print("=" * len(title))


# ------------------------------------------------------------- 1. the names

CLASS_SUFFIXES = (
    ("model provider class  (MPC)", "_MPC"),
    ("its extension         (MPC_EXT)", "_MPC_EXT"),
    ("data provider class   (DPC)", "_DPC"),
    ("its extension         (DPC_EXT)", "_DPC_EXT"),
)


def proposed_names(project: str, class_prefix: str) -> list[tuple[str, str]]:
    """What the generation dialog proposes. The developer may overwrite each one."""
    names = [(role, class_prefix + project + suffix) for role, suffix in CLASS_SUFFIXES]
    names.append(("technical model name", project + "_MDL"))
    names.append(("technical service name", project + "_SRV"))
    return names


def print_names(project: str, class_prefix: str) -> None:
    print(f"project {project}, class prefix {class_prefix}")
    for role, name in proposed_names(project, class_prefix):
        verdict = "" if len(name) <= MAX_ABAP_NAME else f"   <- {len(name)} characters: too long, choose a name by hand"
        print(f"   {role:32} {name:34}{verdict}")


# ------------------------------------------------------- 2. the data model

@dataclass(frozen=True)
class Prop:
    name: str                 # what the consumer sees
    abap: str                 # Dictionary type of the bound ABAP field
    length: int = 0
    decimals: int = 0
    key: bool = False
    edm: str = ""             # set when the model overrides the default mapping
    unit: str = ""            # for an amount or quantity: the property holding its key
    source: str = ""          # the Dictionary field, for the reader


@dataclass
class EntityType:
    name: str
    entity_set: str
    props: list[Prop]
    flags: dict[str, bool] = field(default_factory=dict)   # the entity set's checkboxes

    @property
    def keys(self) -> list[Prop]:
        return [p for p in self.props if p.key]


@dataclass(frozen=True)
class Association:
    name: str
    principal: str            # entity type on the "1" side
    dependent: str            # entity type on the "*" side
    navigation: str           # navigation property on the principal
    constraint: tuple[tuple[str, str], ...]   # (principal property, dependent property)


@dataclass(frozen=True)
class FunctionImport:
    name: str
    http: str
    params: tuple[str, ...]
    returns: str              # entity type, returned as a single entry


PROJECT = "ZBP_IDNUMBERS"
SERVICE = PROJECT + "_SRV"
SERVICE_ROOT = "/sap/opu/odata/sap/" + SERVICE + "/"

MODEL = [
    EntityType(
        "BusinessPartner", "BusinessPartnerSet",
        [
            Prop("BusinessPartner", "CHAR", 10, key=True, source="BUT000-PARTNER"),
            Prop("BusinessPartnerName", "CHAR", 80),
            Prop("CreationDate", "DATS", source="BUT000-CRDAT"),
            Prop("CreationTime", "TIMS", source="BUT000-CRTIM"),
            Prop("IsBlocked", "CHAR", 1, edm="Edm.Boolean", source="BUT000-XBLCK"),
        ],
        {"creatable": True, "updatable": True, "deletable": False, "pageable": True, "addressable": True},
    ),
    EntityType(
        "BPIdentification", "BPIdentificationSet",
        [
            Prop("BusinessPartner", "CHAR", 10, key=True, source="BUT0ID-PARTNER"),
            Prop("BPIdentificationType", "CHAR", 6, key=True, source="BUT0ID-TYPE"),
            Prop("BPIdentificationNumber", "CHAR", 60, key=True, source="BUT0ID-IDNUMBER"),
            Prop("ValidityStartDate", "DATS", source="BUT0ID-VALID_DATE_FROM"),
            Prop("ValidityEndDate", "DATS", source="BUT0ID-VALID_DATE_TO"),
            Prop("Country", "CHAR", 3, source="BUT0ID-COUNTRY"),
        ],
        {"creatable": True, "updatable": True, "deletable": True, "pageable": True, "addressable": True},
    ),
]

ASSOCIATIONS = [
    Association("Assoc_BusinessPartner_BPIdentification", "BusinessPartner", "BPIdentification",
                "to_BPIdentification", (("BusinessPartner", "BusinessPartner"),)),
]

FUNCTION_IMPORTS = [
    FunctionImport("CheckIdentification", "GET", ("BusinessPartner", "BPIdentificationType"), "BPIdentification"),
]

# Default mapping of Dictionary types to EDM types, as the Service Builder proposes
# it when a property is bound to an ABAP field. The page's table says how sure.
EDM_DEFAULT = {
    "CHAR": "Edm.String", "SSTR": "Edm.String", "STRG": "Edm.String", "NUMC": "Edm.String",
    "CLNT": "Edm.String", "LANG": "Edm.String", "CUKY": "Edm.String", "UNIT": "Edm.String",
    "DATS": "Edm.DateTime", "TIMS": "Edm.Time",
    "INT1": "Edm.Byte", "INT2": "Edm.Int16", "INT4": "Edm.Int32", "INT8": "Edm.Int64",
    "DEC": "Edm.Decimal", "CURR": "Edm.Decimal", "QUAN": "Edm.Decimal",
    "FLTP": "Edm.Double", "RAW": "Edm.Binary", "RSTR": "Edm.Binary",
}


def edm_of(p: Prop) -> tuple[str, dict[str, str]]:
    """EDM type and facets of one property. Facets are what $metadata prints."""
    edm = p.edm or EDM_DEFAULT[p.abap]
    facets: dict[str, str] = {}
    if p.key:
        facets["Nullable"] = "false"
    if edm == "Edm.String" and p.length:
        facets["MaxLength"] = str(p.length)
    if edm == "Edm.Decimal":
        facets["Precision"], facets["Scale"] = str(p.length), str(p.decimals)
    if edm in ("Edm.DateTime", "Edm.Time"):
        facets["Precision"] = "0"
    if p.abap == "DATS":
        facets["sap:display-format"] = "Date"
    if p.unit:
        facets["sap:unit"] = p.unit
    return edm, facets


def describe_abap(p: Prop) -> str:
    if p.length and p.decimals:
        return f"{p.abap} {p.length},{p.decimals}"
    if p.length:
        return f"{p.abap} {p.length}"
    return p.abap


def print_type_mapping(props: list[Prop]) -> None:
    for p in props:
        edm, facets = edm_of(p)
        chosen = "  (chosen in the model, not the default)" if p.edm else ""
        facet_text = " ".join(f"{k}={v}" for k, v in facets.items())
        print(f"   {p.source or p.name:24} {describe_abap(p):10} -> {edm:13} {facet_text}{chosen}")


def attrs(d: dict[str, str]) -> str:
    return "".join(f' {k}="{v}"' for k, v in d.items())


def metadata_document() -> list[str]:
    """The $metadata the model provider class builds, shaped like the real one."""
    out = [
        '<edmx:Edmx Version="1.0">',
        "  <edmx:DataServices m:DataServiceVersion=\"2.0\">",
        f'    <Schema Namespace="{SERVICE}" xml:lang="en" sap:schema-version="1">',
    ]
    by_name = {e.name: e for e in MODEL}
    for e in MODEL:
        out.append(f'      <EntityType Name="{e.name}" sap:content-version="1">')
        out.append("        <Key>" + "".join(f'<PropertyRef Name="{k.name}"/>' for k in e.keys) + "</Key>")
        for p in e.props:
            edm, facets = edm_of(p)
            out.append(f'        <Property Name="{p.name}" Type="{edm}"{attrs(facets)}/>')
        for a in ASSOCIATIONS:
            if a.principal == e.name:
                out.append(f'        <NavigationProperty Name="{a.navigation}" Relationship="{SERVICE}.{a.name}"'
                           f' FromRole="FromRole_{a.name}" ToRole="ToRole_{a.name}"/>')
        out.append("      </EntityType>")
    for a in ASSOCIATIONS:
        out.append(f'      <Association Name="{a.name}" sap:content-version="1">')
        out.append(f'        <End Type="{SERVICE}.{a.principal}" Multiplicity="1" Role="FromRole_{a.name}"/>')
        out.append(f'        <End Type="{SERVICE}.{a.dependent}" Multiplicity="*" Role="ToRole_{a.name}"/>')
        out.append("        <ReferentialConstraint>")
        out.append(f'          <Principal Role="FromRole_{a.name}">'
                   + "".join(f'<PropertyRef Name="{p}"/>' for p, _ in a.constraint) + "</Principal>")
        out.append(f'          <Dependent Role="ToRole_{a.name}">'
                   + "".join(f'<PropertyRef Name="{d}"/>' for _, d in a.constraint) + "</Dependent>")
        out.append("        </ReferentialConstraint>")
        out.append("      </Association>")
    out.append(f'      <EntityContainer Name="{SERVICE}_Entities" m:IsDefaultEntityContainer="true">')
    for e in MODEL:
        sap_flags = {f"sap:{k}": ("true" if v else "false") for k, v in e.flags.items()}
        out.append(f'        <EntitySet Name="{e.entity_set}" EntityType="{SERVICE}.{e.name}"{attrs(sap_flags)}/>')
    for a in ASSOCIATIONS:
        out.append(f'        <AssociationSet Name="{a.name}_AssocSet" Association="{SERVICE}.{a.name}">')
        out.append(f'          <End EntitySet="{by_name[a.principal].entity_set}" Role="FromRole_{a.name}"/>')
        out.append(f'          <End EntitySet="{by_name[a.dependent].entity_set}" Role="ToRole_{a.name}"/>')
        out.append("        </AssociationSet>")
    for f in FUNCTION_IMPORTS:
        out.append(f'        <FunctionImport Name="{f.name}" ReturnType="{SERVICE}.{f.returns}"'
                   f' EntitySet="{by_name[f.returns].entity_set}" m:HttpMethod="{f.http}">')
        for prm in f.params:
            out.append(f'          <Parameter Name="{prm}" Type="Edm.String" Mode="In"/>')
        out.append("        </FunctionImport>")
    out.append("      </EntityContainer>")
    out.append("    </Schema>")
    out.append("  </edmx:DataServices>")
    out.append("</edmx:Edmx>")
    return out


# ------------------------------------------------- 3. the generated methods

OPERATIONS = ("GET_ENTITYSET", "GET_ENTITY", "CREATE_ENTITY", "UPDATE_ENTITY", "DELETE_ENTITY")


def dpc_methods(entity_sets: list[str]) -> dict[str, str]:
    """One method per entity set and operation; the name is the set's name in upper case."""
    return {f"{s.upper()}_{op}": s for s in entity_sets for op in OPERATIONS}


def print_generated_classes() -> None:
    mpc = "ZCL_" + PROJECT + "_MPC"
    print(f"{mpc}: one DEFINE method that builds the model above, and for each entity type")
    for e in MODEL:
        print(f"   TS_{e.name.upper():24} a structure with one component per property")
        print(f"   TT_{e.name.upper():24} a table of it, what GET_ENTITYSET returns")
    dpc = "ZCL_" + PROJECT + "_DPC"
    methods = dpc_methods([e.entity_set for e in MODEL])
    print(f"{dpc}: {len(methods)} methods, one per entity set and operation, each generated as")
    print("   RAISE EXCEPTION TYPE /iwbep/cx_mgw_not_impl_exc ... (method not implemented)")
    for name in methods:
        print(f"   {name}")
    print("   plus the interface methods the generated class inherits and dispatches to these:")
    print("   /IWBEP/IF_MGW_APPL_SRV_RUNTIME~GET_ENTITYSET, ~GET_ENTITY, ~CREATE_ENTITY, ~UPDATE_ENTITY,")
    print("   ~DELETE_ENTITY, ~EXECUTE_ACTION, ~GET_EXPANDED_ENTITY, ~GET_EXPANDED_ENTITYSET,")
    print("   ~CHANGESET_BEGIN, ~CHANGESET_PROCESS, ~CHANGESET_END, ~GET_STREAM, ~CREATE_STREAM ...")
    print()
    long_set = "BusinessPartnerIdentificationSet"
    name = f"{long_set.upper()}_GET_ENTITYSET"
    print(f"an entity set called {long_set} would need the method")
    print(f"   {name}  ({len(name)} characters, limit {MAX_ABAP_NAME})")
    print("   so the generator has to shorten it; which letters it drops is a thing to read in your system,")
    print("   not to assume. Entity set names of 16 characters or fewer never meet the limit.")


# ------------------------------------------------------ 4. request dispatch

SEGMENT = re.compile(r"^([A-Za-z_]\w*)(?:\((.*)\))?$")


def parse_keys(text: str, entity: EntityType) -> dict[str, str]:
    """'17100001'  ->  {single key: 17100001};   A='x',B='y'  ->  {A: x, B: y}"""
    if "=" not in text:
        return {entity.keys[0].name: text.strip("'")}
    return {k: v.strip("'") for k, v in (part.split("=", 1) for part in text.split(","))}


def parse_filter(expr: str) -> list[str]:
    """Only the simplest shape, 'P eq V [and ...]', which the framework hands over as ranges."""
    ranges = []
    for clause in expr.split(" and "):
        prop, _, value = clause.partition(" eq ")
        ranges.append(f"{prop}: SIGN=I OPTION=EQ LOW={value.strip().strip(chr(39))}")
    return ranges


def dispatch(http: str, request: str) -> list[str]:
    """Which DPC method a request reaches, and what the framework hands it."""
    path, _, query = request.partition("?")
    options = dict(parse_qsl(query, keep_blank_values=True))
    segments = path.split("/")
    if segments[0] == "$metadata":
        return ["answered from the model provider class: no data provider method runs"]
    first = SEGMENT.match(segments[0])
    name, key_text = first.group(1), first.group(2)
    sets = {e.entity_set: e for e in MODEL}
    imports = {f.name: f for f in FUNCTION_IMPORTS}
    lines: list[str] = []

    if name in imports:
        f = imports[name]
        lines.append(f"/IWBEP/IF_MGW_APPL_SRV_RUNTIME~EXECUTE_ACTION with iv_action_name = {f.name}")
        lines.append("   parameters: " + ", ".join(f"{k}={v.strip(chr(39))}" for k, v in options.items()))
        return lines
    if name not in sets:
        return ["no such entity set in the model: the framework answers with an error before any method"]

    entity = sets[name]
    keys = parse_keys(key_text, entity) if key_text else {}
    target, via_navigation = entity, ""
    if len(segments) > 1 and not segments[1].startswith("$"):
        nav = next(a for a in ASSOCIATIONS if a.navigation == segments[1] and a.principal == entity.name)
        target = next(e for e in MODEL if e.name == nav.dependent)
        via_navigation = segments[1]

    op = {"GET": "GET_ENTITYSET", "POST": "CREATE_ENTITY", "PUT": "UPDATE_ENTITY",
          "MERGE": "UPDATE_ENTITY", "PATCH": "UPDATE_ENTITY", "DELETE": "DELETE_ENTITY"}[http]
    if http == "GET" and keys and not via_navigation:
        op = "GET_ENTITY"
    method = f"{target.entity_set.upper()}_{op}"
    lines.append(method)
    if keys:
        where = "it_key_tab" if not via_navigation else "the source keys of the navigation path"
        lines.append(f"   {where}: " + ", ".join(f"{k}={v}" for k, v in keys.items()))
    if via_navigation:
        lines.append(f"   it_navigation_path: {entity.entity_set} -> {via_navigation}; your method of the target set runs")
    if len(segments) > 1 and segments[1] == "$count":
        lines.append("   $count: your GET_ENTITYSET runs, the framework counts what it returns")
    if "$filter" in options:
        lines.append("   it_filter_select_options: " + "; ".join(parse_filter(options["$filter"])))
        lines.append("   applied by: your method, or nobody")
    paging = {k: options[k] for k in ("$top", "$skip") if k in options}
    if paging:
        lines.append("   is_paging: " + ", ".join(f"{k[1:]}={v}" for k, v in paging.items()) + "   applied by: your method, or nobody")
    if "$orderby" in options:
        lines.append(f"   it_order: {options['$orderby']}   applied by: your method, or nobody")
    if "$inlinecount" in options:
        lines.append("   $inlinecount=allpages: your method fills es_response_context-inlinecount, or the count is missing")
    if "$select" in options:
        lines.append(f"   $select={options['$select']}: applied by the framework when it serialises what you returned")
    if "$expand" in options:
        nav = options["$expand"]
        a = next(x for x in ASSOCIATIONS if x.navigation == nav)
        dep = next(e for e in MODEL if e.name == a.dependent)
        lines.append(f"   $expand={nav}: the framework then calls {dep.entity_set.upper()}_GET_ENTITYSET once per entity returned,")
        lines.append("   unless GET_EXPANDED_ENTITY / GET_EXPANDED_ENTITYSET is redefined to return the deep structure in one go")
    return lines


REQUESTS = [
    ("GET", "$metadata"),
    ("GET", "BusinessPartnerSet"),
    ("GET", "BusinessPartnerSet('17100001')"),
    ("GET", "BusinessPartnerSet('17100001')/to_BPIdentification"),
    ("GET", "BusinessPartnerSet('17100001')?$expand=to_BPIdentification"),
    ("GET", "BPIdentificationSet?$filter=BusinessPartner eq '17100001' and Country eq 'PL'&$top=10&$skip=20"
            "&$orderby=ValidityStartDate desc&$select=BPIdentificationType,BPIdentificationNumber&$inlinecount=allpages"),
    ("GET", "BPIdentificationSet/$count"),
    ("POST", "BPIdentificationSet"),
    ("PUT", "BPIdentificationSet(BusinessPartner='17100001',BPIdentificationType='ZPESEL',BPIdentificationNumber='90010112345')"),
    ("DELETE", "BPIdentificationSet(BusinessPartner='17100001',BPIdentificationType='ZPESEL',BPIdentificationNumber='90010112345')"),
    ("GET", "CheckIdentification?BusinessPartner='17100001'&BPIdentificationType='ZPESEL'"),
    ("GET", "PartnerSet"),
]


# ------------------------------------------------------- 5. regeneration

def regeneration() -> None:
    first = dpc_methods(["BusinessPartnerSet", "BPIdentificationSet"])
    redefined_in_ext = ["BUSINESSPARTNERSET_GET_ENTITY", "BPIDENTIFICATIONSET_GET_ENTITYSET"]
    print("generation 1: DPC has", len(first), "methods; the developer redefines in DPC_EXT:")
    for m in redefined_in_ext:
        print("   ", m)
    print()
    print("the model changes: BPIdentificationSet is renamed BPIdentificationNumberSet,")
    print("BPIdentificationTypeSet is added, and the project is generated again")
    second = dpc_methods(["BusinessPartnerSet", "BPIdentificationNumberSet", "BPIdentificationTypeSet"])
    print()
    print(f"generation 2: DPC rewritten with {len(second)} methods:")
    print(f"   {len(second.keys() - first.keys())} new, {len(first.keys() - second.keys())} gone, {len(first.keys() & second.keys())} unchanged")
    print("   DPC_EXT: not touched by the generator, still holds the 2 redefinitions")
    for m in redefined_in_ext:
        if m in second:
            print(f"   {m:40} still redefines a method of the superclass: fine")
        else:
            print(f"   {m:40} redefines a method the superclass no longer has:")
            print("   " + " " * 40 + " DPC_EXT does not activate until this redefinition is renamed or deleted")


# ------------------------------------------------------------------- main

def main() -> None:
    section("1. The names the generation dialog proposes")
    print_names(PROJECT, "ZCL_")
    print()
    print_names("API_BUSINESS_PARTNER", "CL_")
    print()
    print_names("GWSAMPLE_BASIC", "/IWBEP/CL_")
    print()
    print(f"service document, once the service is registered in the hub: {SERVICE_ROOT}")
    print(f"$metadata:                                                   {SERVICE_ROOT}$metadata")

    section("2. From the Dictionary field to the EDM property")
    for e in MODEL:
        print(f"entity type {e.name} (entity set {e.entity_set}), keys: " + ", ".join(k.name for k in e.keys))
        print_type_mapping(e.props)
    print()
    print("the same rule for the amount and quantity types, which this model does not have:")
    print_type_mapping([
        Prop("VBAP-POSNR", "NUMC", 6, source="VBAP-POSNR"),
        Prop("NetAmount", "CURR", 15, 2, unit="Currency", source="VBAP-NETWR"),
        Prop("Currency", "CUKY", 5, source="VBAP-WAERK"),
        Prop("Quantity", "QUAN", 15, 3, unit="Unit", source="VBAP-KWMENG"),
        Prop("Unit", "UNIT", 3, source="VBAP-VRKME"),
        Prop("PartnerGuid", "RAW", 16, source="BUT000-PARTNER_GUID"),
    ])

    section("3. The $metadata document the model provider class answers with")
    for line in metadata_document():
        print(line)

    section("4. The classes the generator writes")
    print_generated_classes()

    section("5. Which method a request reaches, and what the framework hands it")
    for http, request in REQUESTS:
        print(f"{http} {SERVICE_ROOT}{request}")
        for line in dispatch(http, request):
            print("   " + line)
        print()

    section("6. Generating again: what survives")
    regeneration()


if __name__ == "__main__":
    main()
