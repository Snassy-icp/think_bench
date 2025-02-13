module {
    // Core ID types
    public type ConceptId = Nat;
    public type RelationshipId = Nat;
    public type RelationshipTypeId = Nat;

    // Core relationship type IDs (initialized during canister setup)
    public let RELATIONSHIP_TYPE_IS_A: RelationshipTypeId = 0;
    public let RELATIONSHIP_TYPE_HAS_A: RelationshipTypeId = 1;
    public let RELATIONSHIP_TYPE_PART_OF: RelationshipTypeId = 2;
    public let RELATIONSHIP_TYPE_PROPERTY_OF: RelationshipTypeId = 3;

    // Inference types
    public type InferenceSource = {
        #Direct: RelationshipId;                  // Directly asserted relationship
        #Transitive: {                            // Inferred through transitivity
            first: RelationshipId;                // A IS-A B
            second: RelationshipId;               // B IS-A C
            probability: Probability;             // Combined probability
        };
        #Symmetric: RelationshipId;               // Inferred through symmetry (A->B implies B->A)
    };

    public type InferredRelationship = {
        relationship: Relationship;
        source: InferenceSource;
    };

    public type InferenceQuery = {
        startingConcept: ConceptId;              // Start inference from this concept
        relationshipType: ?RelationshipTypeId;    // Optional: only infer this type
        maxDepth: ?Nat;                          // Optional: maximum inference depth
        minProbability: ?Probability;            // Optional: minimum probability threshold
        minConfidence: ?Confidence;              // Optional: minimum confidence threshold
    };

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

    // Generic fraction type for representing ratios
    public type Fraction = {
        numerator: Nat;
        denominator: Nat;
    };

    // Unit fraction type for values constrained to 0 <= n <= 1
    public type UnitFraction = Fraction;

    // Specific unit fraction types for different semantic uses
    public type Probability = UnitFraction;
    public type Confidence = UnitFraction;
    public type Reliability = UnitFraction;

    // User reliability tracking
    public type UserReliability = {
        principalId: Principal;
        score: Reliability;
        lastUpdated: Int;
    };

    // Creator type for provenance tracking
    public type Creator = {
        principalId: Principal;
        timestamp: Int;  // Time.now() value
    };

    // Core concept type
    public type Concept = {
        id: ConceptId;
        name: Text;
        description: ?Text;
        creator: Creator;  // Added creator field
        created: Int;
        modified: Int;
        outgoingRelationships: [RelationshipId];
        incomingRelationships: [RelationshipId];
        metadata: [(Text, Text)];
    };

    // Validation types
    public type ValidationRule = {
        #RequiredMetadata: [Text];  // Required metadata keys
        #UniqueTarget;              // Target must be unique for this relationship type
        #NoSelfReference;           // Source cannot equal target
        #CustomRule: {              // Custom validation rule
            name: Text;
            description: Text;      // Description of what the rule validates
            errorCode: Text;        // Error code to return if validation fails
        };
    };

    // Enhanced relationship type properties
    public type RelationshipTypeProperties = {
        logical: {
            transitive: Bool;      // If A->B->C then A->C
            symmetric: Bool;       // If A->B then B->A
            reflexive: Bool;       // A->A always holds
            irreflexive: Bool;     // A->A never holds
        };
        inheritance: {
            inheritable: Bool;     // Whether relationship inherits through IS-A
            probabilityMode: {     // How probabilities combine during inference
                #MULTIPLY;         // p1 * p2 (like IS-A chains)
                #MINIMUM;          // min(p1, p2) (conservative)
                #MAXIMUM;          // max(p1, p2) (optimistic)
                #OVERRIDE;         // Most specific wins
            };
        };
        validation: [ValidationRule];
    };

    // Relationship type definition
    public type RelationshipTypeDef = {
        id: RelationshipTypeId;
        name: Text;
        description: ?Text;
        properties: RelationshipTypeProperties;
        metadata: [(Text, Text)];
        status: {
            #ACTIVE;
            #DEPRECATED: {
                replacedBy: ?RelationshipTypeId;
                reason: Text;
            };
        };
    };

    // Core relationship type
    public type Relationship = {
        id: RelationshipId;
        fromConceptId: ConceptId;
        toConceptId: ConceptId;
        relationshipTypeId: RelationshipTypeId;
        probability: Probability;
        confidence: Confidence;
        creator: Creator;
        metadata: [(Text, Text)];
    };

    // Query types
    public type ConceptQuery = {
        namePattern: ?Text;
        metadata: [(Text, Text)];
        hasInstances: ?Bool;
        isInstance: ?Bool;
        creator: ?Principal;  // Added creator filter
    };

    public type RelationshipQuery = {
        fromConceptId: ?ConceptId;
        toConceptId: ?ConceptId;
        relationshipTypeId: ?RelationshipTypeId;
        minProbability: ?Probability;
        maxProbability: ?Probability;
        metadata: [(Text, Text)];
        creator: ?Principal;  // Added creator filter
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

    // Enhanced error types
    public type Error = {
        #ValidationError: {
            code: Text;
            message: Text;
            details: ?{
                field: Text;
                constraint: Text;
                value: Text;
            };
        };
        #NotFound: Text;
        #AlreadyExists: Text;
        #SystemError: Text;
        #InvalidOperation: Text;
        #PermissionDenied: {
            operation: Text;
            resource: Text;
            reason: Text;
        };
        #InvalidConfidence: {
            value: Text;
            reason: Text;
        };
    };
}
