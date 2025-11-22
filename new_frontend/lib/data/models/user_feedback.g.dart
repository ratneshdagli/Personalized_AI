// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_feedback.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetUserFeedbackCollection on Isar {
  IsarCollection<UserFeedback> get userFeedbacks => this.collection();
}

const UserFeedbackSchema = CollectionSchema(
  name: r'UserFeedback',
  id: 5824897119201723406,
  properties: {
    r'appPackage': PropertySchema(
      id: 0,
      name: r'appPackage',
      type: IsarType.string,
    ),
    r'messageContent': PropertySchema(
      id: 1,
      name: r'messageContent',
      type: IsarType.string,
    ),
    r'reason': PropertySchema(
      id: 2,
      name: r'reason',
      type: IsarType.string,
    ),
    r'timestamp': PropertySchema(
      id: 3,
      name: r'timestamp',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _userFeedbackEstimateSize,
  serialize: _userFeedbackSerialize,
  deserialize: _userFeedbackDeserialize,
  deserializeProp: _userFeedbackDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _userFeedbackGetId,
  getLinks: _userFeedbackGetLinks,
  attach: _userFeedbackAttach,
  version: '3.1.0+1',
);

int _userFeedbackEstimateSize(
  UserFeedback object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.appPackage.length * 3;
  bytesCount += 3 + object.messageContent.length * 3;
  bytesCount += 3 + object.reason.length * 3;
  return bytesCount;
}

void _userFeedbackSerialize(
  UserFeedback object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.appPackage);
  writer.writeString(offsets[1], object.messageContent);
  writer.writeString(offsets[2], object.reason);
  writer.writeDateTime(offsets[3], object.timestamp);
}

UserFeedback _userFeedbackDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = UserFeedback();
  object.appPackage = reader.readString(offsets[0]);
  object.id = id;
  object.messageContent = reader.readString(offsets[1]);
  object.reason = reader.readString(offsets[2]);
  object.timestamp = reader.readDateTime(offsets[3]);
  return object;
}

P _userFeedbackDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _userFeedbackGetId(UserFeedback object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _userFeedbackGetLinks(UserFeedback object) {
  return [];
}

void _userFeedbackAttach(
    IsarCollection<dynamic> col, Id id, UserFeedback object) {
  object.id = id;
}

extension UserFeedbackQueryWhereSort
    on QueryBuilder<UserFeedback, UserFeedback, QWhere> {
  QueryBuilder<UserFeedback, UserFeedback, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension UserFeedbackQueryWhere
    on QueryBuilder<UserFeedback, UserFeedback, QWhereClause> {
  QueryBuilder<UserFeedback, UserFeedback, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension UserFeedbackQueryFilter
    on QueryBuilder<UserFeedback, UserFeedback, QFilterCondition> {
  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      appPackageEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'appPackage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      appPackageGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'appPackage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      appPackageLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'appPackage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      appPackageBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'appPackage',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      appPackageStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'appPackage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      appPackageEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'appPackage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      appPackageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'appPackage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      appPackageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'appPackage',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      appPackageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'appPackage',
        value: '',
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      appPackageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'appPackage',
        value: '',
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      messageContentEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'messageContent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      messageContentGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'messageContent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      messageContentLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'messageContent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      messageContentBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'messageContent',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      messageContentStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'messageContent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      messageContentEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'messageContent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      messageContentContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'messageContent',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      messageContentMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'messageContent',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      messageContentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'messageContent',
        value: '',
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      messageContentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'messageContent',
        value: '',
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition> reasonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      reasonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      reasonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition> reasonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      reasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      reasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      reasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition> reasonMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      reasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reason',
        value: '',
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      reasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reason',
        value: '',
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      timestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      timestampGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      timestampLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterFilterCondition>
      timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timestamp',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension UserFeedbackQueryObject
    on QueryBuilder<UserFeedback, UserFeedback, QFilterCondition> {}

extension UserFeedbackQueryLinks
    on QueryBuilder<UserFeedback, UserFeedback, QFilterCondition> {}

extension UserFeedbackQuerySortBy
    on QueryBuilder<UserFeedback, UserFeedback, QSortBy> {
  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy> sortByAppPackage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appPackage', Sort.asc);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy>
      sortByAppPackageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appPackage', Sort.desc);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy>
      sortByMessageContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageContent', Sort.asc);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy>
      sortByMessageContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageContent', Sort.desc);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy> sortByReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.asc);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy> sortByReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.desc);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy> sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy> sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension UserFeedbackQuerySortThenBy
    on QueryBuilder<UserFeedback, UserFeedback, QSortThenBy> {
  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy> thenByAppPackage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appPackage', Sort.asc);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy>
      thenByAppPackageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appPackage', Sort.desc);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy>
      thenByMessageContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageContent', Sort.asc);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy>
      thenByMessageContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageContent', Sort.desc);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy> thenByReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.asc);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy> thenByReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.desc);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy> thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QAfterSortBy> thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension UserFeedbackQueryWhereDistinct
    on QueryBuilder<UserFeedback, UserFeedback, QDistinct> {
  QueryBuilder<UserFeedback, UserFeedback, QDistinct> distinctByAppPackage(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'appPackage', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QDistinct> distinctByMessageContent(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'messageContent',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QDistinct> distinctByReason(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<UserFeedback, UserFeedback, QDistinct> distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }
}

extension UserFeedbackQueryProperty
    on QueryBuilder<UserFeedback, UserFeedback, QQueryProperty> {
  QueryBuilder<UserFeedback, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<UserFeedback, String, QQueryOperations> appPackageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'appPackage');
    });
  }

  QueryBuilder<UserFeedback, String, QQueryOperations>
      messageContentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'messageContent');
    });
  }

  QueryBuilder<UserFeedback, String, QQueryOperations> reasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reason');
    });
  }

  QueryBuilder<UserFeedback, DateTime, QQueryOperations> timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }
}
