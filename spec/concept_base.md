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
Concepts can be:
- Concrete entities (e.g., "Black Beauty")
- Categories (e.g., "Horse", "Mammal")
- Abstract ideas (e.g., "Speed", "Intelligence")

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
   
2. HAS-A Relationship
   - Represents possession or composition
   - Example: "Horse HAS-A Tail" (probability: 999/1000)
   - Can include quantity/cardinality

3. PART-OF Relationship
   - Represents component relationships
   - Inverse of HAS-A
   - Example: "Heart PART-OF Mammal" (probability: 1/1)

4. PROPERTY-OF Relationship
   - Links concepts to their properties
   - Can include value and units
   - Example: "Color PROPERTY-OF Black Beauty = Black" (probability: 1/1)

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
  - Direct assertion
  - Logical deduction (with references to premises)
  - External reference/source
  - Experimental/empirical evidence
- Temporal Context (when applicable)
- Conflict References (links to conflicting relationships)

### 3. Logical Inference System
The system maintains both explicit and derived relationships:
- Explicit relationships are directly asserted
- Derived relationships are computed through logical inference
- Each derived relationship maintains references to its premises
- Probability propagation follows mathematical rules:
  - AND operations: multiply probabilities (a/b * c/d = ac/bd)
  - OR operations: P(A∪B) = P(A) + P(B) - P(A∩B)
- Example:
  ```
  Explicit: Black Beauty IS-A Horse (probability: 1/1)
  Explicit: Horse IS-A Mammal (probability: 1/1)
  Derived: Black Beauty IS-A Mammal (probability: 1/1, premises: above two relationships)

  Example with uncertainty:
  Explicit: X IS-A Bird (probability: 95/100)
  Explicit: Bird CAN Fly (probability: 90/100)
  Derived: X CAN Fly (probability: 171/200, premises: above two relationships)
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
- Comparison: For evaluating relative likelihoods

#### 4.3 Dynamic Interpretation
Probabilities can be dynamically interpreted based on context:
- Categorical mapping (ALWAYS, MOSTLY, SOMETIMES, RARELY, NEVER)
- Percentage representation for display
- Confidence intervals for statistical analysis
- Boolean thresholds for decision making

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
