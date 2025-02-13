module {
    // Core ID types
    public type ConceptId = Nat;
    public type RelationshipId = Nat;
    public type RelationshipTypeId = Nat;

    // Value type for properties and metadata
    public type Value = {
        #Text: Text;
        #Int: Int;
        #Float: Float;
        #Bool: Bool;
        #Array: [Value];
        #Object: [(Text, Text)];
    };

    // Duration for temporal aspects
    public type Duration = {
        nanoseconds: Int;
    };

    // Probability representation
    public type Probability = {
        numerator: Nat;
        denominator: Nat;
    };

    // Core concept type
    public type Concept = {
        id: ConceptId;
        name: Text;
        description: ?Text;
        created: Int;  // Timestamp
        modified: Int; // Timestamp
        outgoingRelationships: [RelationshipId];
        incomingRelationships: [RelationshipId];
        metadata: [(Text, Text)];
    };

    // Relationship type properties
    public type RelationshipTypeProperties = {
        logical: {
            transitive: Bool;
            symmetric: Bool;
            reflexive: Bool;
            irreflexive: Bool;
            antisymmetric: Bool;
            asymmetric: Bool;
            functional: Bool;
            inverseFunctional: Bool;
        };
        inheritance: {
            inheritable: Bool;
            probabilityMode: {
                #MULTIPLY;
                #MINIMUM;
                #MAXIMUM;
                #OVERRIDE;
            };
        };
    };

    // Relationship type definition
    public type RelationshipTypeDef = {
        id: RelationshipTypeId;
        name: Text;
        properties: RelationshipTypeProperties;
        metadata: [(Text, Text)];
    };

    // Core relationship type
    public type Relationship = {
        id: RelationshipId;
        fromConceptId: ConceptId;
        toConceptId: ConceptId;
        relationshipTypeId: RelationshipTypeId;
        probability: Probability;
        metadata: [(Text, Text)];
    };

    // Query types
    public type ConceptQuery = {
        namePattern: ?Text;
        metadata: [(Text, Text)];
        hasInstances: ?Bool;
        isInstance: ?Bool;
    };

    public type RelationshipQuery = {
        fromConceptId: ?ConceptId;
        toConceptId: ?ConceptId;
        relationshipTypeId: ?RelationshipTypeId;
        minProbability: ?Probability;
        maxProbability: ?Probability;
        metadata: [(Text, Text)];
    };

    // Result types
    public type Result<Ok, Err> = {
        #ok : Ok;
        #err : Err;
    };

    public type QueryResult<T> = {
        #ok: {
            items: [T];
            total: Nat;
            page: Nat;
            pageSize: Nat;
        };
        #err: Text;
    };

    // Error types
    public type Error = {
        #ValidationError: Text;
        #NotFound: Text;
        #AlreadyExists: Text;
        #SystemError: Text;
    };
}
