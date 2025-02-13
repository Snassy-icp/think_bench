# Concept Base Specification

## Implementation Platform
This concept base system will be implemented on the Internet Computer (ICP) blockchain platform:

### Architecture
- Backend: Motoko canister implementing the core concept base functionality
  - Stores and manages concepts and relationships
  - Handles logical inference and conflict resolution
  - Exposes an API for concept manipulation and querying
- Frontend: Web client for interaction with the concept base
  - User interface for adding/editing concepts and relationships
  - Visualization of concept relationships and inference chains
  - Query interface for exploring the concept base

### Key Platform Benefits
- Persistence and reliability through the Internet Computer infrastructure
- Built-in authentication and access control
- Scalable storage and computation
- Potential for integration with other ICP services and canisters

## Overview
This document specifies the structure and operations of a concept base system designed for logical reasoning and algebraic operations over concepts and their relationships.

## Core Components

### 1. Concepts
A concept is the fundamental unit in our system. Each concept represents a distinct idea, entity, or category. 

#### 1.1 Concept Types
A concept's nature emerges from its relationships rather than being explicitly typed:
- A concept is concrete if it has no instances (no other concepts that IS-A this concept)
- A concept is a category if it has instances (other concepts that IS-A this concept)
- A concept is abstract if it only appears in property relationships
- These classifications are computed dynamically and can change as relationships are added or removed

#### 1.2 Concept Properties
Each concept can have properties:
- Intrinsic properties (e.g., "color", "weight", "age")
- Computed properties (derived from relationships or logical inference)
- Meta-properties (e.g., confidence score, source reference, timestamp)

### 2. Relationships
Relationships connect concepts to each other. 

#### 2.1 Core Relationship Types
1. IS-A Relationship
   - Represents hierarchical classification
   - Transitive: If A IS-A B and B IS-A C, then A IS-A C
   - Probability combines multiplicatively through transitive inference
   - Inherited probabilities can be overridden by direct assertions
   
2. HAS-A Relationship
   - Represents possession or composition
   - Example: "Horse HAS-A Tail" (probability: 999/1000)
   - Can include quantity/cardinality
   - Inherited by instances (e.g., if Horse HAS-A Tail, Black Beauty inherits this)
   - Inherited probabilities can be overridden by direct assertions

3. PART-OF Relationship
   - Represents component relationships
   - Inverse of HAS-A
   - Example: "Heart PART-OF Mammal" (probability: 1/1)
   - Inherits inversely through IS-A relationships
   - Inherited probabilities can be overridden by direct assertions

4. PROPERTY-OF Relationship
   - Links concepts to their properties
   - Can include value and units
   - Example: "Color PROPERTY-OF Black Beauty = Black" (probability: 1/1)
   - Properties inherit through IS-A relationships
   - Inherited probabilities can be overridden by direct assertions

#### 2.2 Relationship Properties
Each relationship has:
- Source Concept
- Target Concept
- Relationship Type
- Probability: Represented as a ratio of natural numbers (Nat/Nat)
  - Examples: 
    - Certainty: 1/1
    - High probability: 99/100
    - Even chance: 1/2
    - Impossibility: 0/1
  - Properties:
    - Always normalized to simplest form
    - Preserved through mathematical operations
    - Allows for infinite precision
- Provenance:
  - Direct assertion (overrides inherited probabilities)
  - Logical deduction (with references to premises)
  - Inheritance (references source relationship and inheritance path)
  - External reference/source
  - Experimental/empirical evidence
- Temporal Context (when applicable)
- Conflict References (links to conflicting relationships)
- Inheritance Status:
  - #EXPLICIT // Directly asserted, overrides inheritance
  - #INHERITED // Derived through inheritance rules
  - #COMPUTED // Derived through other inference rules

### 3. Logical Inference System
The system maintains both explicit and derived relationships:
- Explicit relationships are directly asserted (override inherited ones)
- Derived relationships are computed through logical inference
- Each derived relationship maintains references to its premises
- Inheritance hierarchy:
  1. Explicit assertions (highest precedence)
  2. Direct logical inference
  3. Inherited relationships (lowest precedence)

#### 3.1 Inference Rules
1. Transitive Inference (AND-chain):
   ```
   A IS-A B (p1)
   B IS-A C (p2)
   ∴ A IS-A C (p1 * p2)
   ```

2. Multiple Paths (OR):
   ```
   A IS-A C via path1 (p1)
   A IS-A C via path2 (p2)
   ∴ A IS-A C (p1 + p2 - p1*p2)  // Union probability
   ```

3. Property Inheritance:
   ```
   A IS-A B (p1)
   B HAS-PROPERTY X (p2)
   ∴ A HAS-PROPERTY X (min(p1, p2))  // Conservative estimate
   ```

4. HAS-A Inheritance:
   ```
   A IS-A B (p1)
   B HAS-A X (p2)
   ∴ A HAS-A X (p1 * p2)  // Multiplicative because both conditions must hold
   
   Example:
   Black Beauty IS-A Horse (p: 1/1)
   Horse HAS-A Tail (p: 92/100)
   ∴ Black Beauty HAS-A Tail (p: 92/100)  // Since 1/1 * 92/100 = 92/100
   
   Override example:
   If later added:
   Black Beauty HAS-A Tail (p: 1/1)  // Direct observation
   This overrides the inherited probability as it's explicit knowledge
   ```

5. Inverse Relationships:
   ```
   A HAS-A B (p1)
   ∴ B PART-OF A (p1)  // Probability preserved
   ```

6. Contradictory Evidence:
   ```
   A IS-A B (p1)
   A IS-NOT-A B (p2)
   ∴ Conflict detected if: p1 + p2 > 1
   Resolution: Use max(p1, p2) if sources equally reliable
   ```

#### 3.2 Inference Strategies
1. Conservative Inference:
   - Uses min() for property inheritance
   - Ensures derived probabilities never exceed source probabilities
   - Suitable for safety-critical reasoning

2. Optimistic Inference:
   - Uses max() for alternative evidence
   - Suitable for hypothesis generation
   - May require additional validation

3. Balanced Inference:
   - Uses weighted averages based on source reliability
   - Considers temporal aspects
   - Default strategy for most cases

#### 3.3 Inference Chain Validation
- Each step in inference chain must maintain probability invariants
- Circular reasoning detection
- Contradiction detection
- Example:
  ```
  Given:
  Black Beauty IS-A Horse (p: 1/1)
  Horse IS-A Mammal (p: 1/1)
  Mammal IS-A Animal (p: 1/1)
  
  Inferred:
  Step 1: Black Beauty IS-A Mammal (p: 1/1)
  Step 2: Black Beauty IS-A Animal (p: 1/1)
  
  Validation:
  - No probability degradation (all 1/1)
  - No circular references
  - Chain: Black Beauty -> Horse -> Mammal -> Animal
  ```

#### 3.4 Performance Optimization
- Cache frequently used inference chains
- Precompute common property inheritances
- Lazy evaluation of long inference chains
- Prioritize short inference paths over long ones

#### 3.5 Inheritance Override Rules
1. Explicit Override:
   ```
   Given inherited:
   A IS-A B (p1)
   B HAS-A X (p2)
   ∴ A HAS-A X (p1 * p2)  // Inherited probability

   If explicitly asserted:
   A HAS-A X (p3)  // Direct knowledge
   ∴ A HAS-A X (p3)  // Overrides inherited probability
   ```

2. Multiple Inheritance Resolution:
   ```
   A IS-A B (p1)
   A IS-A C (p2)
   B HAS-A X (p3)
   C HAS-A X (p4)
   ∴ A HAS-A X (combined probability using OR rule)
   
   If explicitly asserted:
   A HAS-A X (p5)
   ∴ A HAS-A X (p5)  // Overrides all inherited probabilities
   ```

3. Temporal Override:
   ```
   At t1: A HAS-A X (inherited: p1)
   At t2: A HAS-A X (explicit: p2)
   At t3: Source of inheritance changes
   ∴ A HAS-A X (p2)  // Explicit assertion remains until explicitly changed
   ```

4. Inheritance Chain Breaking:
   ```
   A IS-A B IS-A C
   C HAS-A X (p1)
   B HAS-A X (p2)  // More specific, overrides inheritance from C
   ∴ A inherits from B, not C
   ```

### 4. Probability System

#### 4.1 Representation
```motoko
type Probability = {
    numerator: Nat;
    denominator: Nat;
    invariant: numerator <= denominator;  // Ensures p <= 1
};

// Constructor function to enforce invariant
func createProbability(n: Nat, d: Nat) : ?Probability {
    if (d == 0 or n > d) {
        return null;  // Invalid probability
    };
    // Returns normalized probability with n <= d
    let normalized = normalize(n, d);
    ?{
        numerator = normalized.0;
        denominator = normalized.1;
        invariant = normalized.0 <= normalized.1;
    }
};
```

#### 4.2 Core Operations
- Validation: Ensures 0 ≤ p ≤ 1 (numerator ≤ denominator)
- Normalization: Reduces fraction to simplest form while preserving invariant
- Multiplication: For combining sequential probabilities
  ```motoko
  // Example implementation
  func multiply(p1: Probability, p2: Probability) : ?Probability {
      createProbability(
          p1.numerator * p2.numerator,
          p1.denominator * p2.denominator
      )
  }
  ```
- Addition: For combining alternative paths (with validation)
  ```motoko
  // Example implementation
  func add(p1: Probability, p2: Probability) : ?Probability {
      let n = p1.numerator * p2.denominator + p2.numerator * p1.denominator;
      let d = p1.denominator * p2.denominator;
      createProbability(n, d)
  }
  ```
- Complement: For negation (1 - p)
  ```motoko
  // Example implementation
  func complement(p: Probability) : Probability {
      {
          numerator = p.denominator - p.numerator;
          denominator = p.denominator;
          invariant = (p.denominator - p.numerator) <= p.denominator;
      }
  }
  ```
- Comparison: For evaluating relative likelihoods
  ```motoko
  // Example implementations
  func isEqual(p1: Probability, p2: Probability) : Bool {
      p1.numerator * p2.denominator == p2.numerator * p1.denominator
  };

  func isLessThan(p1: Probability, p2: Probability) : Bool {
      p1.numerator * p2.denominator < p2.numerator * p1.denominator
  };
  ```
- Conditional Probability: For dependent events
  ```motoko
  // P(A|B) = P(A AND B) / P(B)
  func conditional(pAandB: Probability, pB: Probability) : ?Probability {
      if (pB.numerator == 0) {
          null  // Cannot condition on impossible event
      } else {
          createProbability(
              pAandB.numerator * pB.denominator,
              pAandB.denominator * pB.numerator
          )
      }
  }
  ```
- Min/Max Operations: For combining evidence from multiple sources
  ```motoko
  func min(p1: Probability, p2: Probability) : Probability {
      if (isLessThan(p1, p2)) { p1 } else { p2 }
  };

  func max(p1: Probability, p2: Probability) : Probability {
      if (isLessThan(p1, p2)) { p2 } else { p1 }
  };
  ```

#### 4.3 Dynamic Interpretation
Probabilities can be dynamically interpreted based on context:
- Categorical mapping:
  ```motoko
  type Category = {
      #ALWAYS;     // p = 1
      #ALMOST_ALWAYS; // p >= 0.95
      #MOSTLY;     // p >= 0.75
      #OFTEN;      // p >= 0.6
      #SOMETIMES;  // p >= 0.4
      #RARELY;     // p >= 0.25
      #ALMOST_NEVER; // p >= 0.05
      #NEVER;      // p = 0
  };

  func toCategory(p: Probability) : Category {
      let ratio = Float.fromInt(p.numerator) / Float.fromInt(p.denominator);
      switch(ratio) {
          case 1.0 { #ALWAYS };
          case (x) if x >= 0.95 { #ALMOST_ALWAYS };
          case (x) if x >= 0.75 { #MOSTLY };
          case (x) if x >= 0.60 { #OFTEN };
          case (x) if x >= 0.40 { #SOMETIMES };
          case (x) if x >= 0.25 { #RARELY };
          case (x) if x >= 0.05 { #ALMOST_NEVER };
          case 0.0 { #NEVER };
      }
  }
  ```
- Display formats:
  ```motoko
  type DisplayFormat = {
      #RATIO;      // "3/4"
      #DECIMAL;    // "0.75"
      #PERCENTAGE; // "75%"
      #CATEGORY;   // "MOSTLY"
  };

  func format(p: Probability, fmt: DisplayFormat) : Text {
      switch(fmt) {
          case (#RATIO) { 
              Int.toText(p.numerator) # "/" # Int.toText(p.denominator)
          };
          case (#DECIMAL) {
              // Format to 3 decimal places
              let ratio = Float.fromInt(p.numerator) / Float.fromInt(p.denominator);
              formatDecimal(ratio, 3)
          };
          case (#PERCENTAGE) {
              let percent = (Float.fromInt(p.numerator) * 100.0) / Float.fromInt(p.denominator);
              formatDecimal(percent, 1) # "%"
          };
          case (#CATEGORY) {
              debug_show(toCategory(p))
          };
      }
  }
  ```

#### 4.4 Mathematical Properties
- Preserved precision through operations
- No floating point errors
- Exact representation of rational probabilities
- Well-defined behavior for all operations
- Transitive consistency in inference chains
- Guaranteed bounds: 0 ≤ p ≤ 1
- Safe arithmetic: Operations that would violate probability bounds return null

#### 4.5 Error Handling
- Invalid probability construction (n > d) returns null
- Operations that would result in invalid probabilities return null
- System must handle null results gracefully
- Validation occurs at:
  - Probability creation
  - After each arithmetic operation
  - Before storing in the concept base
  - When importing external data

### 5. Conflict Management
The system explicitly tracks and manages conflicts:

#### 5.1 Probability-Based Conflict Resolution
- Conflicts are evaluated based on probability differences
- Non-overlapping probability ranges may indicate no real conflict
- Example:
  ```
  Statement 1: Birds CAN Fly (probability: 90/100)
  Statement 2: Penguin CANNOT Fly (probability: 99/100)
  Resolution: No conflict as they represent different statistical populations
  ```

#### 5.2 Conflict Resolution
- Explicit conflict records linking conflicting relationships
- Resolution strategies:
  - Probability-based (compare rational numbers)
  - Temporal (prefer more recent)
  - Source-based (prefer more authoritative source)
  - Exception-based (explicit exception rules)

#### 5.3 Exception Handling
- Exceptions are represented as high-probability contrary relationships
- Example: 
  ```
  Birds CAN Fly (probability: 90/100)
  Penguins ARE Birds (probability: 1/1)
  Penguins CANNOT Fly (probability: 999/1000)
  ```

## Questions for Discussion
1. Should we support relationship types beyond IS-A? (e.g., HAS-A, PART-OF)
2. How should we handle conflicting information or exceptions?
3. Should concepts have properties/attributes beyond their relationships?
4. How should we represent and handle uncertainty in relationships?
5. Should we support different types of logical reasoning beyond transitive inference?

## Next Steps
1. Define the complete set of relationship types
2. Specify the logical inference rules with probability propagation
3. Design the data structure for storing concepts and relationships
4. Implement probability arithmetic operations
5. Define the API for adding, querying, and manipulating concepts
6. Implement conflict detection and resolution mechanisms
7. Create a query language for complex concept relationships

## Implementation

### 1. Types

```motoko
// Core types for the concept base system

// ID types and counters
type ConceptId = Nat;
type RelationshipId = Nat;

// Stable state for ID generation
stable var nextConceptId : Nat = 0;
stable var nextRelationshipId : Nat = 0;

// Helper functions for ID generation
func generateConceptId() : ConceptId {
    let id = nextConceptId;
    nextConceptId += 1;
    id
};

func generateRelationshipId() : RelationshipId {
    let id = nextRelationshipId;
    nextRelationshipId += 1;
    id
};

// Main concept type
type Concept = {
    id: ConceptId;
    name: Text;
    description: ?Text;
    created: Time.Time;
    modified: Time.Time;
    outgoingRelationships: [RelationshipId];  // Where this concept is the source
    incomingRelationships: [RelationshipId];  // Where this concept is the target
    metadata: [(Text, Text)];
};

// Query types for flexible searching
type ConceptQuery = {
    namePattern: ?Text;
    metadata: [(Text, Text)];
    hasInstances: ?Bool;        // For finding categories
    isInstance: ?Bool;          // For finding concrete entities
    hasPropertyRelations: ?Bool; // For finding abstract concepts
};

// Core relationship type definitions
type RelationshipTypeId = Nat;

// Consolidated relationship properties
type RelationshipTypeProperties = {
    // Logical properties (consolidated from core and algebraic)
    logical: {
        transitive: Bool;      // If A->B->C then A->C
        symmetric: Bool;       // If A->B then B->A
        reflexive: Bool;       // A->A always holds
        irreflexive: Bool;     // A->A never holds
        antisymmetric: Bool;   // If A->B and B->A then A=B
        asymmetric: Bool;      // If A->B then not B->A
        functional: Bool;      // Each source has unique target
        inverseFunctional: Bool; // Each target has unique source
    };

    // Inheritance configuration
    inheritance: {
        inheritable: Bool;  // Whether relationship inherits through IS-A
        probabilityMode: {
            #MULTIPLY;  // p1 * p2 (like IS-A chains)
            #MINIMUM;   // min(p1, p2) (conservative)
            #MAXIMUM;   // max(p1, p2) (optimistic)
            #OVERRIDE; // Most specific wins
        };
        temporalMode: {
            #INHERIT_RANGE;     // Inherits temporal range intersection
            #INHERIT_LATEST;    // Uses most recent temporal context
            #INHERIT_EARLIEST;  // Uses earliest temporal context
        };
    };

    // Relationship interactions
    interactions: {
        inverse: ?{
            relationshipTypeId: RelationshipTypeId;
            probabilityMapping: {
                #PRESERVE;     // Same probability
                #COMPLEMENT;   // 1 - p
                #RECIPROCAL;   // 1/p
                #CUSTOM: Text; // Custom formula
            };
        };
        implies: [{
            relationshipTypeId: RelationshipTypeId;
            probabilityMapping: Text;  // Formula for derived probability
        }];
        conflicts: [{
            relationshipTypeId: RelationshipTypeId;
            resolutionStrategy: {
                #PROBABILITY_BASED: {
                    threshold: Probability;  // Conflict if difference exceeds threshold
                };
                #TEMPORAL_BASED: {
                    preferRecent: Bool;
                };
                #SOURCE_BASED: {
                    authorityHierarchy: [Text];  // Ordered list of authoritative sources
                };
            };
        }];
    };

    // Validation (using structured predicates instead of text)
    validation: {
        sourceConstraints: [Predicate];
        targetConstraints: [Predicate];
        relationshipConstraints: [RelationshipPredicate];
    };
};

// Structured predicate types for validation
type Predicate = {
    #HAS_RELATIONSHIP: {
        relationshipTypeId: RelationshipTypeId;
        minCount: ?Nat;
        maxCount: ?Nat;
    };
    #HAS_PROPERTY: {
        name: Text;
        value: Value;
    };
    #COMPOSITE: {
        operator: {#AND; #OR; #NOT};
        predicates: [Predicate];
    };
};

type RelationshipPredicate = {
    #PROBABILITY_RANGE: {
        min: ?Probability;
        max: ?Probability;
    };
    #TEMPORAL_RANGE: {
        minAge: ?Duration;
        maxAge: ?Duration;
    };
    #PROVENANCE: {
        requiredSources: [Text];
    };
    #COMPOSITE: {
        operator: {#AND; #OR; #NOT};
        predicates: [RelationshipPredicate];
    };
};

// Stable storage for relationship types
stable var nextRelationshipTypeId: Nat = 0;
stable var relationshipTypes: [(RelationshipTypeId, RelationshipTypeDef)] = [];

// Core relationship type IDs (initialized during canister setup)
let RELATIONSHIP_TYPE_IS_A: RelationshipTypeId = 0;
let RELATIONSHIP_TYPE_HAS_A: RelationshipTypeId = 1;
let RELATIONSHIP_TYPE_PART_OF: RelationshipTypeId = 2;
let RELATIONSHIP_TYPE_PROPERTY_OF: RelationshipTypeId = 3;

// Main relationship type
type Relationship = {
    id: RelationshipId;
    fromConceptId: ConceptId;
    toConceptId: ConceptId;
    relationshipTypeId: RelationshipTypeId;
    probability: Probability;
    provenance: Provenance;
    inheritanceStatus: InheritanceStatus;
    temporal: ?{
        validFrom: Time.Time;
        validTo: ?Time.Time;
        inferredFrom: ?[{
            relationshipId: RelationshipId;
            temporalRule: Text;
        }];
    };
    conflicts: [{
        relationshipId: RelationshipId;
        resolutionStrategy: {
            #PROBABILITY_BASED;
            #TEMPORAL_BASED;
            #SOURCE_BASED;
            #MANUAL: Text;
        };
        status: {
            #UNRESOLVED;
            #RESOLVED_IN_FAVOR;
            #RESOLVED_AGAINST;
        };
    }];
    metadata: [(Text, Text)];
};

// Result types
type QueryResult<T> = {
    #ok: {
        items: [T];
        total: Nat;
        page: Nat;
        pageSize: Nat;
    };
    #err: Text;
};
```

### 2. Backend API

```motoko
actor ConceptBase {
    // Concept Management
    public shared(msg) func createConcept(
        name: Text,
        description: ?Text,
        metadata: ?[(Text, Text)]
    ) : async Result<ConceptId, Text>;

    public shared(msg) func updateConcept(
        id: ConceptId,
        name: ?Text,
        description: ?Text,
        metadata: ?[(Text, Text)]
    ) : async Result<(), Text>;

    public query func getConcept(id: ConceptId) : async Result<Concept, Text>;

    public query func queryConcepts(
        query: ConceptQuery,
        page: Nat,
        pageSize: Nat
    ) : async QueryResult<Concept>;

    // Relationship Management
    public shared(msg) func assertRelationship(
        fromConceptId: ConceptId,
        toConceptId: ConceptId,
        relationshipTypeId: RelationshipTypeId,
        probability: Probability,
        metadata: ?[(Text, Text)]
    ) : async Result<RelationshipId, Text>;

    public shared(msg) func updateRelationship(
        id: RelationshipId,
        probability: ?Probability,
        metadata: ?[(Text, Text)]
    ) : async Result<(), Text>;

    public query func getRelationship(id: RelationshipId) : async Result<Relationship, Text>;

    public query func queryRelationships(
        query: RelationshipQuery,
        page: Nat,
        pageSize: Nat
    ) : async QueryResult<Relationship>;

    // Traversal API
    public query func traverseRelationships(
        query: RelationshipTraversalQuery
    ) : async [Relationship];

    public query func getRelatedConcepts(
        conceptId: ConceptId,
        direction: TraversalDirection,
        relationshipTypes: [RelationshipTypeId]
    ) : async [ConceptId];

    // Helper queries
    public query func getInstances(conceptId: ConceptId) : async [ConceptId];
    public query func getCategories(conceptId: ConceptId) : async [ConceptId];
    public query func getProperties(conceptId: ConceptId) : async [Relationship];
    
    // Inference API
    public query func inferRelationships(
        fromConceptId: ConceptId,
        relationshipTypeId: ?RelationshipTypeId,
        maxDepth: ?Nat
    ) : async QueryResult<Relationship>;

    public query func validateInference(
        relationships: [RelationshipId]
    ) : async Result<{
        valid: Bool;
        explanation: Text;
        conflicts: [RelationshipId];
    }, Text>;

    // Relationship Type Management
    public shared(msg) func createRelationshipType(
        name: Text,
        properties: RelationshipTypeProperties,
        metadata: [(Text, Text)]
    ) : async Result<RelationshipTypeId, Text>;

    public query func getRelationshipType(
        id: RelationshipTypeId
    ) : async Result<RelationshipTypeDef, Text>;

    public query func listRelationshipTypes(
    ) : async [(RelationshipTypeId, RelationshipTypeDef)];
};
```

### 3. Relationship Type Management

```motoko
// Advanced probability computation rules
type ProbabilityRule = {
    #MULTIPLY;      // Independent events: P(A∧B) = P(A)*P(B)
    #OR;           // Alternative paths: P(A∨B) = P(A) + P(B) - P(A)*P(B)
    #AND;          // Joint probability: P(A∧B)
    #CONDITIONAL;  // P(A|B) = P(A∧B)/P(B)
    #BAYES;       // P(B|A) = P(A|B)*P(B)/P(A)
    #NOISY_OR: {   // P(A) = 1 - ∏(1 - pi) for independent causes
        baseProbability: Probability;
        leakProbability: Probability;
    };
    #MARKOV: {     // Conditional probability tables
        states: [Text];
        transitions: [(Text, Text, Probability)];
    };
    #CUSTOM: {     // Custom probability formula
        formula: Text;
        parameters: [(Text, Probability)];
    };
};

// Closure computation for relationship types
func computeTransitiveClosure(
    relationships: [Relationship],
    relationshipType: RelationshipTypeId
) : [Relationship] {
    let typeDef = getRelationshipType(relationshipType);
    if (not typeDef.properties.algebraicProperties.transitive) {
        return relationships;
    };

    var closure = relationships;
    var changed = true;
    
    while (changed) {
        changed := false;
        for (r1 in closure.vals()) {
            for (r2 in closure.vals()) {
                if (r1.targetId == r2.sourceId) {
                    let newProb = multiply(r1.probability, r2.probability);
                    let newRel = {
                        sourceId = r1.sourceId;
                        targetId = r2.targetId;
                        probability = newProb;
                        // ... other fields ...
                    };
                    if (not exists(closure, newRel)) {
                        closure := Array.append(closure, [newRel]);
                        changed := true;
                    };
                };
            };
        };
    };
    
    closure
};

// Example relationship type definitions with inference rules
let SIBLING_OF = registerRelationshipType({
    name = "SIBLING_OF";
    properties = {
        algebraicProperties = {
            symmetric = true;
            irreflexive = true;
            transitive = false;
        };
        compositionRules = [{
            // If A SIBLING_OF B and B SIBLING_OF C then A SIBLING_OF C
            first = RELATIONSHIP_TYPE_SIBLING_OF;
            result = RELATIONSHIP_TYPE_SIBLING_OF;
            probabilityRule = #MULTIPLY;
        }];
        interactionRules = [{
            // Siblings must have same parents
            otherType = RELATIONSHIP_TYPE_HAS_PARENT;
            interaction = #IMPLIES;
        }];
    };
});

let GREATER_THAN = registerRelationshipType({
    name = "GREATER_THAN";
    properties = {
        algebraicProperties = {
            transitive = true;
            asymmetric = true;
            irreflexive = true;
            strictOrder = true;
        };
        compositionRules = [{
            first = RELATIONSHIP_TYPE_GREATER_THAN;
            result = RELATIONSHIP_TYPE_GREATER_THAN;
            probabilityRule = #MINIMUM;  // Conservative estimate
        }];
    };
});

// Validation rules with examples
func validateRelationshipAssertion(
    source: ConceptId,
    target: ConceptId,
    relationshipType: RelationshipTypeId,
    probability: Probability
) : Result<(), Text> {
    let typeDef = getRelationshipType(relationshipType);
    
    // Check reflexivity constraints
    if (source == target) {
        if (typeDef.properties.algebraicProperties.irreflexive) {
            return #err("Relationship cannot be reflexive");
        };
        if (not typeDef.properties.algebraicProperties.reflexive) {
            return #err("Relationship must be explicitly marked as reflexive");
        };
    };
    
    // Check functional constraints
    if (typeDef.properties.algebraicProperties.functional) {
        let existing = findRelationships(source, relationshipType);
        if (existing.size() > 0) {
            return #err("Functional relationship already exists for source");
        };
    };
    
    // Check order constraints
    if (typeDef.properties.algebraicProperties.strictOrder) {
        // Check for cycles
        if (pathExists(target, source, relationshipType)) {
            return #err("Would create cycle in strict order");
        };
    };
    
    // Check probability constraints
    if (typeDef.properties.algebraicProperties.equivalence) {
        if (not isEqual(probability, createProbability(1, 1))) {
            return #err("Equivalence relationships must have probability 1");
        };
    };
    
    #ok()
};

// Example inference patterns
type InferencePattern = {
    #Transitive: {
        through: RelationshipTypeId;
    };
    #Symmetric: {
        relationship: RelationshipTypeId;
    };
    #Inverse: {
        forward: RelationshipTypeId;
        backward: RelationshipTypeId;
    };
    #Distribution: {
        outer: RelationshipTypeId;
        inner: RelationshipTypeId;
    };
    #Composition: {
        first: RelationshipTypeId;
        second: RelationshipTypeId;
        result: RelationshipTypeId;
    };
};

// Example usage:
// 1. Transitive closure of GREATER_THAN
let ordered = computeTransitiveClosure(relationships, RELATIONSHIP_TYPE_GREATER_THAN);

// 2. Symmetric inference for SIBLING_OF
if (exists(A, B, SIBLING_OF)) {
    infer(B, A, SIBLING_OF, sameProbability);
};

// 3. Distribution of HAS-A over IS-A
// If Dog IS-A Mammal and Mammal HAS-A Heart
// Then Dog HAS-A Heart (with computed probability)
if (exists(A, B, IS_A) and exists(B, C, HAS_A)) {
    let p1 = getProbability(A, B, IS_A);
    let p2 = getProbability(B, C, HAS_A);
    infer(A, C, HAS_A, multiply(p1, p2));
};
```

### 4. Bidirectional Relationship Indexing

```motoko
// Bidirectional relationship indexing
type RelationshipIndex = {
    // Forward index: source -> [(relationshipType, target)]
    forwardIndex: [(ConceptId, [(RelationshipTypeId, ConceptId)])];
    // Reverse index: target -> [(relationshipType, source)]
    reverseIndex: [(ConceptId, [(RelationshipTypeId, ConceptId)])];
    // Type index: relationshipType -> [(source, target)]
    typeIndex: [(RelationshipTypeId, [(ConceptId, ConceptId)])];
};

// Stable storage for indexes
stable var relationshipIndex: RelationshipIndex = {
    forwardIndex = [];
    reverseIndex = [];
    typeIndex = [];
};

// Index maintenance functions
func indexRelationship(relationship: Relationship) {
    // Add to forward index
    addToForwardIndex(
        relationship.sourceId,
        relationship.relationshipTypeId,
        relationship.targetId
    );
    
    // Add to reverse index
    addToReverseIndex(
        relationship.targetId,
        relationship.relationshipTypeId,
        relationship.sourceId
    );
    
    // Add to type index
    addToTypeIndex(
        relationship.relationshipTypeId,
        relationship.sourceId,
        relationship.targetId
    );
};

// Enhanced query functions for bidirectional traversal
type TraversalDirection = {
    #FORWARD;     // Follow relationships from source to target
    #REVERSE;     // Follow relationships from target to source
    #BOTH;        // Follow in both directions
};

type RelationshipTraversalQuery = {
    startingConcept: ConceptId;
    relationshipTypes: [RelationshipTypeId];
    direction: TraversalDirection;
    maxDepth: ?Nat;
    minProbability: ?Probability;
};

// Traversal function
func traverseRelationships(query: RelationshipTraversalQuery) : [Relationship] {
    var results: [Relationship] = [];
    var visited: [(ConceptId, RelationshipTypeId)] = [];
    var queue: [(ConceptId, Nat)] = [(query.startingConcept, 0)];
    
    while (queue.size() > 0) {
        let (currentId, depth) = queue[0];
        queue := Array.slice(queue, 1, queue.size());
        
        if (Option.get(query.maxDepth, 2**32 - 1) >= depth) {
            // Get forward relationships
            if (query.direction == #FORWARD or query.direction == #BOTH) {
                let forward = getForwardRelationships(currentId, query.relationshipTypes);
                for (rel in forward.vals()) {
                    if (not visited.contains((rel.targetId, rel.relationshipTypeId))) {
                        results := Array.append(results, [rel]);
                        queue := Array.append(queue, [(rel.targetId, depth + 1)]);
                        visited := Array.append(visited, [(rel.targetId, rel.relationshipTypeId)]);
                    };
                };
            };
            
            // Get reverse relationships
            if (query.direction == #REVERSE or query.direction == #BOTH) {
                let reverse = getReverseRelationships(currentId, query.relationshipTypes);
                for (rel in reverse.vals()) {
                    if (not visited.contains((rel.sourceId, rel.relationshipTypeId))) {
                        results := Array.append(results, [rel]);
                        queue := Array.append(queue, [(rel.sourceId, depth + 1)]);
                        visited := Array.append(visited, [(rel.sourceId, rel.relationshipTypeId)]);
                    };
                };
            };
        };
    };
    
    results
};

// Example queries:
// 1. Get all instances of a concept (reverse IS-A traversal)
func getInstances(conceptId: ConceptId) : [ConceptId] {
    let query = {
        startingConcept = conceptId;
        relationshipTypes = [RELATIONSHIP_TYPE_IS_A];
        direction = #REVERSE;
        maxDepth = null;
        minProbability = ?createProbability(1, 1);
    };
    let relationships = traverseRelationships(query);
    Array.map(relationships, func(r: Relationship) : ConceptId { r.sourceId })
};

// 2. Get all categories a concept belongs to (forward IS-A traversal)
func getCategories(conceptId: ConceptId) : [ConceptId] {
    let query = {
        startingConcept = conceptId;
        relationshipTypes = [RELATIONSHIP_TYPE_IS_A];
        direction = #FORWARD;
        maxDepth = null;
        minProbability = null;
    };
    let relationships = traverseRelationships(query);
    Array.map(relationships, func(r: Relationship) : ConceptId { r.targetId })
};

// 3. Get all properties and parts (multiple relationship types)
func getPropertiesAndParts(conceptId: ConceptId) : [Relationship] {
    traverseRelationships({
        startingConcept = conceptId;
        relationshipTypes = [
            RELATIONSHIP_TYPE_HAS_A,
            RELATIONSHIP_TYPE_PROPERTY_OF
        ];
        direction = #FORWARD;
        maxDepth = ?1;
        minProbability = null;
    })
};

// Add to Backend API:
public query func traverseConcepts(
    query: RelationshipTraversalQuery
) : async [Relationship];

public query func getRelatedConcepts(
    conceptId: ConceptId,
    direction: TraversalDirection,
    relationshipTypes: [RelationshipTypeId]
) : async [ConceptId];

// Example usage:
// From Horse, find all instances (Black Beauty)
let horseInstances = getInstances(horseId);

// From Black Beauty, find all categories (Horse, Mammal, Animal)
let blackBeautyCategories = getCategories(blackBeautyId);

// From Horse, find all properties and parts
let horseProperties = getPropertiesAndParts(horseId);
```

### 5. Helper Functions

```motoko
// Helper functions for relationship management
func addRelationship(relationship: Relationship) : async Result<(), Text> {
    // Update source concept's outgoing relationships
    switch (concepts.get(relationship.fromConceptId)) {
        case (?concept) {
            concept.outgoingRelationships := 
                Array.append(concept.outgoingRelationships, [relationship.id]);
        };
        case null return #err("Source concept not found");
    };

    // Update target concept's incoming relationships
    switch (concepts.get(relationship.toConceptId)) {
        case (?concept) {
            concept.incomingRelationships := 
                Array.append(concept.incomingRelationships, [relationship.id]);
        };
        case null return #err("Target concept not found");
    };

    relationships.put(relationship.id, relationship);
    #ok()
};

func removeRelationship(relationshipId: RelationshipId) : async Result<(), Text> {
    switch (relationships.get(relationshipId)) {
        case (?relationship) {
            // Remove from source concept
            switch (concepts.get(relationship.fromConceptId)) {
                case (?concept) {
                    concept.outgoingRelationships := 
                        Array.filter(concept.outgoingRelationships, 
                            func(id: RelationshipId) : Bool { id != relationshipId });
                };
                case null return #err("Source concept not found");
            };

            // Remove from target concept
            switch (concepts.get(relationship.toConceptId)) {
                case (?concept) {
                    concept.incomingRelationships := 
                        Array.filter(concept.incomingRelationships, 
                            func(id: RelationshipId) : Bool { id != relationshipId });
                };
                case null return #err("Target concept not found");
            };

            relationships.delete(relationshipId);
            #ok()
        };
        case null #err("Relationship not found");
    }
};

// Enhanced query functions
func getConceptOutgoingRelationships(
    conceptId: ConceptId,
    relationshipType: ?RelationshipTypeId
) : [Relationship] {
    switch (concepts.get(conceptId)) {
        case (?concept) {
            let rels = Array.mapFilter(concept.outgoingRelationships, 
                func(id: RelationshipId) : ?Relationship { relationships.get(id) });
            switch (relationshipType) {
                case (?typeId) Array.filter(rels, 
                    func(r: Relationship) : Bool { r.relationshipTypeId == typeId });
                case null rels;
            }
        };
        case null [];
    }
};

func getConceptIncomingRelationships(
    conceptId: ConceptId,
    relationshipType: ?RelationshipTypeId
) : [Relationship] {
    switch (concepts.get(conceptId)) {
        case (?concept) {
            let rels = Array.mapFilter(concept.incomingRelationships, 
                func(id: RelationshipId) : ?Relationship { relationships.get(id) });
            switch (relationshipType) {
                case (?typeId) Array.filter(rels, 
                    func(r: Relationship) : Bool { r.relationshipTypeId == typeId });
                case null rels;
            }
        };
        case null [];
    }
};