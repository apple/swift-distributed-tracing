//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Tracing

extension SpanAttributeName {
    /// - See: DatabaseAttributes
    public enum Database {
        /// - See: DatabaseAttributes
        public static let system = "db.system"
        /// - See: DatabaseAttributes
        public static let connectionString = "db.connection_string"
        /// - See: DatabaseAttributes
        public static let user = "db.user"
        /// - See: DatabaseAttributes
        public static let name = "db.name"
        /// - See: DatabaseAttributes
        public static let statement = "db.statement"
        /// - See: DatabaseAttributes
        public static let operation = "db.operation"

        /// - See: DatabaseAttributes.MSSQLAttributes
        public enum MSSQL {
            /// - See: DatabaseAttributes.MSSQLAttributes
            public static let instanceName = "db.mssql.instance_name"
        }

        /// - See: DatabaseAttributes.CassandraAttributes
        public enum Cassandra {
            /// - See: DatabaseAttributes.CassandraAttributes
            public static let keyspace = "db.cassandra.keyspace"
        }

        /// - See: DatabaseAttributes.HBaseAttributes
        public enum HBase {
            /// - See: DatabaseAttributes.HBaseAttributes
            public static let namespace = "db.hbase.namespace"
        }

        /// - See: DatabaseAttributes.RedisAttributes
        public enum Redis {
            /// - See: DatabaseAttributes.RedisAttributes
            public static let databaseIndex = "db.redis.database_index"
        }

        /// - See: DatabaseAttributes.MongoDBAttributes
        public enum MongoDB {
            /// - See: DatabaseAttributes.MongoDBAttributes
            public static let collection = "db.mongodb.collection"
        }

        /// - See: DatabaseAttributes.SQLAttributes
        public enum SQL {
            /// - See: DatabaseAttributes.SQLAttributes
            public static let table = "db.sql.table"
        }
    }
}

#if swift(>=5.2)
extension SpanAttributes {
    /// Semantic database client call attributes.
    public var db: DatabaseAttributes {
        get {
            .init(attributes: self)
        }
        set {
            self = newValue.attributes
        }
    }
}

/// Semantic conventions for database client calls as defined in the OpenTelemetry spec.
///
/// - SeeAlso: [OpenTelemetry: Database attributes](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/database.md)
@dynamicMemberLookup
public struct DatabaseAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    // MARK: - General

    public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// An identifier for the database management system (DBMS) product being used. See [OpenTelemetry: Database attributes](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/database.md) for a list of well-known identifiers.
        public var system: Key<String> { .init(name: SpanAttributeName.Database.system) }

        /// The connection string used to connect to the database. It is recommended to remove embedded credentials.
        public var connectionString: Key<String> { .init(name: SpanAttributeName.Database.connectionString) }

        /// Username for accessing the database.
        public var user: Key<String> { .init(name: SpanAttributeName.Database.user) }

        /// If no [tech-specific attribute](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/semantic_conventions/database.md#call-level-attributes-for-specific-technologies)
        /// is defined, this attribute is used to report the name of the database being accessed. For commands that switch the database, this should be set to the target database (even if the command fails).
        ///
        /// - Note: In some SQL databases, the database name to be used is called "schema name".
        public var name: Key<String> { .init(name: SpanAttributeName.Database.name) }

        /// The database statement being executed.
        ///
        /// - Note: The value may be sanitized to exclude sensitive information.
        public var statement: Key<String> { .init(name: SpanAttributeName.Database.statement) }

        /// The name of the operation being executed, e.g. the [MongoDB command name](https://docs.mongodb.com/manual/reference/command/#database-operations)
        /// such as `findAndModify`, or the SQL keyword.
        ///
        /// - Note: When setting this to an SQL keyword, it is not recommended to attempt any client-side parsing of `db.statement` just to get this
        /// property, but it should be set if the operation name is provided by the library being instrumented.
        /// If the SQL statement has an ambiguous operation, or performs more than one operation, this value may be omitted.
        public var operation: Key<String> { .init(name: SpanAttributeName.Database.operation) }
    }

    // MARK: - MSSQL

    /// Semantic MSSQL client call attributes.
    public var mssql: MSSQLAttributes {
        get {
            .init(attributes: self.attributes)
        }
        set {
            self.attributes = newValue.attributes
        }
    }

    /// Semantic conventions for MSSQL client calls as defined in the OpenTelemetry spec.
    public struct MSSQLAttributes: SpanAttributeNamespace {
        public var attributes: SpanAttributes

        public init(attributes: SpanAttributes) {
            self.attributes = attributes
        }

        public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
            public init() {}

            /// The Microsoft SQL Server [instance name](https://docs.microsoft.com/en-us/sql/connect/jdbc/building-the-connection-url?view=sql-server-ver15)
            /// connecting to. This name is used to determine the port of a named instance.
            ///
            /// - Note: If setting a `db.mssql.instance_name`, `net.peer.port` is no longer required (but still recommended if non-standard).
            public var instanceName: Key<String> { .init(name: SpanAttributeName.Database.MSSQL.instanceName) }
        }
    }

    // MARK: - Cassandra

    /// Semantic Cassandra client call attributes.
    public var cassandra: CassandraAttributes {
        get {
            .init(attributes: self.attributes)
        }
        set {
            self.attributes = newValue.attributes
        }
    }

    /// Semantic conventions for Cassandra client calls as defined in the OpenTelemetry spec.
    public struct CassandraAttributes: SpanAttributeNamespace {
        public var attributes: SpanAttributes

        public init(attributes: SpanAttributes) {
            self.attributes = attributes
        }

        public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
            public init() {}

            /// The name of the keyspace being accessed. To be used instead of the generic `db.name` attribute.
            public var keyspace: Key<String> { .init(name: SpanAttributeName.Database.Cassandra.keyspace) }
        }
    }

    // MARK: - HBase

    /// Semantic HBase client call attributes.
    public var hbase: HBaseAttributes {
        get {
            .init(attributes: self.attributes)
        }
        set {
            self.attributes = newValue.attributes
        }
    }

    /// Semantic conventions for HBase client calls as defined in the OpenTelemetry spec.
    public struct HBaseAttributes: SpanAttributeNamespace {
        public var attributes: SpanAttributes

        public init(attributes: SpanAttributes) {
            self.attributes = attributes
        }

        public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
            public init() {}

            /// The [HBase namespace](https://hbase.apache.org/book.html#_namespace) being accessed.
            /// To be used instead of the generic `db.name` attribute.
            public var namespace: Key<String> { .init(name: SpanAttributeName.Database.HBase.namespace) }
        }
    }

    // MARK: - Redis

    /// Semantic Redis client call attributes.
    public var redis: RedisAttributes {
        get {
            .init(attributes: self.attributes)
        }
        set {
            self.attributes = newValue.attributes
        }
    }

    /// Semantic conventions for Redis client calls as defined in the OpenTelemetry spec.
    public struct RedisAttributes: SpanAttributeNamespace {
        public var attributes: SpanAttributes

        public init(attributes: SpanAttributes) {
            self.attributes = attributes
        }

        public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
            public init() {}

            /// The index of the database being accessed as used in the [`SELECT` command](https://redis.io/commands/select),
            /// provided as an integer. To be used instead of the generic `db.name` attribute.
            public var databaseIndex: Key<Int> { .init(name: SpanAttributeName.Database.Redis.databaseIndex) }
        }
    }

    // MARK: - MongoDB

    /// Semantic MongoDB client call attributes.
    public var mongodb: MongoDBAttributes {
        get {
            .init(attributes: self.attributes)
        }
        set {
            self.attributes = newValue.attributes
        }
    }

    /// Semantic conventions for MongoDB client calls as defined in the OpenTelemetry spec.
    public struct MongoDBAttributes: SpanAttributeNamespace {
        public var attributes: SpanAttributes

        public init(attributes: SpanAttributes) {
            self.attributes = attributes
        }

        public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
            public init() {}

            /// The collection being accessed within the database stated in `db.name`.
            public var collection: Key<String> { .init(name: SpanAttributeName.Database.MongoDB.collection) }
        }
    }

    // MARK: - SQL

    /// Semantic SQL client call attributes.
    public var sql: SQLAttributes {
        get {
            .init(attributes: self.attributes)
        }
        set {
            self.attributes = newValue.attributes
        }
    }

    /// Semantic conventions for SQL client calls as defined in the OpenTelemetry spec.
    public struct SQLAttributes: SpanAttributeNamespace {
        public var attributes: SpanAttributes

        public init(attributes: SpanAttributes) {
            self.attributes = attributes
        }

        public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
            public init() {}

            /// The name of the primary table that the operation is acting upon, including the schema name (if applicable).
            ///
            /// - Note: It is not recommended to attempt any client-side parsing of `db.statement` just to get this property,
            /// but it should be set if it is provided by the library being instrumented.
            /// If the operation is acting upon an anonymous table, or more than one table, this value MUST NOT be set.
            public var table: Key<String> { .init(name: SpanAttributeName.Database.SQL.table) }
        }
    }
}
#endif
