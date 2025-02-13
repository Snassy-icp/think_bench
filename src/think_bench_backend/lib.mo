import Types "Types";
import Array "mo:base/Array";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Principal "mo:base/Principal";

module {
    // Concept Management
    public func createConcept(
        concepts: [(Types.ConceptId, Types.Concept)],
        name: Text,
        description: ?Text,
        metadata: ?[(Text, Text)],
        nextId: Nat,
        caller: Principal
    ) : Types.Result<Types.Concept, Types.Error> {
        let concept : Types.Concept = {
            id = nextId;
            name = name;
            description = description;
            creator = {
                principalId = caller;
                timestamp = Time.now();
            };
            created = Time.now();
            modified = Time.now();
            outgoingRelationships = [];
            incomingRelationships = [];
            metadata = Option.get(metadata, []);
        };
        #ok(concept)
    };

    public func validateConcept(concept: Types.Concept) : Bool {
        if (concept.name == "") {
            return false;
        };
        true
    };

    public func validateConceptModification(
        concept: Types.Concept,
        caller: Principal
    ) : Types.Result<(), Types.Error> {
        if (concept.creator.principalId != caller) {
            return #err(#PermissionDenied({
                operation = "modify";
                resource = "concept";
                reason = "Only the creator can modify this concept";
            }));
        };
        #ok()
    };

    // Relationship Management
    public func createRelationship(
        concepts: [(Types.ConceptId, Types.Concept)],
        fromConceptId: Types.ConceptId,
        toConceptId: Types.ConceptId,
        relationshipTypeId: Types.RelationshipTypeId,
        probability: Types.Probability,
        metadata: ?[(Text, Text)],
        nextId: Nat,
        caller: Principal
    ) : Types.Result<Types.Relationship, Types.Error> {
        // Validate concepts exist
        switch (Array.find<(Types.ConceptId, Types.Concept)>(concepts, func(entry) = entry.0 == fromConceptId)) {
            case null return #err(#NotFound("Source concept not found"));
            case (?_) {};
        };
        
        switch (Array.find<(Types.ConceptId, Types.Concept)>(concepts, func(entry) = entry.0 == toConceptId)) {
            case null return #err(#NotFound("Target concept not found"));
            case (?_) {};
        };

        // Validate probability
        if (probability.denominator == 0 or probability.numerator > probability.denominator) {
            return #err(#ValidationError({
                code = "INVALID_PROBABILITY";
                message = "Invalid probability values";
                details = ?{
                    field = "probability";
                    constraint = "0 <= p <= 1";
                    value = Nat.toText(probability.numerator) # "/" # Nat.toText(probability.denominator);
                };
            }));
        };

        let relationship : Types.Relationship = {
            id = nextId;
            fromConceptId = fromConceptId;
            toConceptId = toConceptId;
            relationshipTypeId = relationshipTypeId;
            probability = probability;
            creator = {
                principalId = caller;
                timestamp = Time.now();
            };
            metadata = Option.get(metadata, []);
        };
        #ok(relationship)
    };

    public func validateRelationshipModification(
        relationship: Types.Relationship,
        caller: Principal
    ) : Types.Result<(), Types.Error> {
        if (relationship.creator.principalId != caller) {
            return #err(#PermissionDenied({
                operation = "modify";
                resource = "relationship";
                reason = "Only the creator can modify this relationship";
            }));
        };
        #ok()
    };

    public func validateRelationship(relationship: Types.Relationship) : Bool {
        if (relationship.probability.denominator == 0) {
            return false;
        };
        if (relationship.probability.numerator > relationship.probability.denominator) {
            return false;
        };
        true
    };

    // Relationship Type Management
    public func createRelationshipType(
        types: [(Types.RelationshipTypeId, Types.RelationshipTypeDef)],
        name: Text,
        description: ?Text,
        properties: Types.RelationshipTypeProperties,
        metadata: [(Text, Text)],
        nextId: Nat
    ) : Types.Result<Types.RelationshipTypeDef, Types.Error> {
        // Check if name is already taken
        switch (Array.find<(Types.RelationshipTypeId, Types.RelationshipTypeDef)>(
            types,
            func((_, def)) = def.name == name
        )) {
            case (?_) return #err(#ValidationError({
                code = "NAME_EXISTS";
                message = "Relationship type with this name already exists";
                details = ?{
                    field = "name";
                    constraint = "unique";
                    value = name;
                };
            }));
            case null {};
        };

        // Validate properties
        if (properties.logical.reflexive and properties.logical.irreflexive) {
            return #err(#ValidationError({
                code = "INVALID_PROPERTIES";
                message = "Relationship type cannot be both reflexive and irreflexive";
                details = ?{
                    field = "properties.logical";
                    constraint = "mutually_exclusive";
                    value = "reflexive and irreflexive";
                };
            }));
        };

        let relationshipType : Types.RelationshipTypeDef = {
            id = nextId;
            name = name;
            description = description;
            properties = properties;
            metadata = metadata;
            status = #ACTIVE;
        };

        #ok(relationshipType)
    };

    public func validateRelationshipAgainstType(
        relationship: Types.Relationship,
        relationshipType: Types.RelationshipTypeDef
    ) : Types.Result<(), Types.Error> {
        // Check if type is deprecated
        switch (relationshipType.status) {
            case (#DEPRECATED(info)) {
                return #err(#ValidationError({
                    code = "DEPRECATED_TYPE";
                    message = "Relationship type is deprecated: " # info.reason;
                    details = switch(info.replacedBy) {
                        case (?replacement) ?{
                            field = "relationshipTypeId";
                            constraint = "deprecated";
                            value = "Use type " # Nat.toText(replacement) # " instead";
                        };
                        case null null;
                    };
                }));
            };
            case (#ACTIVE) {};
        };

        // Apply validation rules
        for (rule in relationshipType.properties.validation.vals()) {
            switch (rule) {
                case (#RequiredMetadata(keys)) {
                    for (key in keys.vals()) {
                        switch (Array.find<(Text, Text)>(relationship.metadata, func(entry) = entry.0 == key)) {
                            case null return #err(#ValidationError({
                                code = "MISSING_METADATA";
                                message = "Required metadata key missing: " # key;
                                details = ?{
                                    field = "metadata";
                                    constraint = "required";
                                    value = key;
                                };
                            }));
                            case (?_) {};
                        };
                    };
                };
                case (#UniqueTarget) {
                    // This would need access to all relationships to validate
                    // For now, we'll implement this in the main actor
                };
                case (#NoSelfReference) {
                    if (relationship.fromConceptId == relationship.toConceptId) {
                        return #err(#ValidationError({
                            code = "SELF_REFERENCE";
                            message = "Self-referential relationships not allowed for this type";
                            details = ?{
                                field = "toConceptId";
                                constraint = "no_self_reference";
                                value = Nat.toText(relationship.toConceptId);
                            };
                        }));
                    };
                };
                case (#CustomRule(rule)) {
                    return #err(#ValidationError({
                        code = rule.errorCode;
                        message = rule.description;
                        details = null;
                    }));
                };
            };
        };

        // Check logical properties
        if (relationshipType.properties.logical.irreflexive and relationship.fromConceptId == relationship.toConceptId) {
            return #err(#ValidationError({
                code = "IRREFLEXIVE_VIOLATION";
                message = "Irreflexive relationship cannot reference same concept";
                details = ?{
                    field = "toConceptId";
                    constraint = "irreflexive";
                    value = Nat.toText(relationship.toConceptId);
                };
            }));
        };

        #ok()
    };

    // Query Functions
    public func queryConcepts(
        concepts: [(Types.ConceptId, Types.Concept)],
        criteria: Types.ConceptQuery
    ) : [Types.Concept] {
        var results : [Types.Concept] = [];
        
        for ((_, concept) in concepts.vals()) {
            var matches = true;
            
            // Creator matching
            switch (criteria.creator) {
                case (?creator) {
                    if (concept.creator.principalId != creator) {
                        matches := false;
                    };
                };
                case null {};
            };
            
            // Name pattern matching
            switch (criteria.namePattern) {
                case (?pattern) {
                    if (not textContains(concept.name, pattern)) {
                        matches := false;
                    };
                };
                case null {};
            };
            
            // Metadata matching
            for ((key, value) in criteria.metadata.vals()) {
                switch (Array.find<(Text, Text)>(concept.metadata, func(entry) = entry.0 == key and entry.1 == value)) {
                    case null matches := false;
                    case (?_) {};
                };
            };
            
            if (matches) {
                results := Array.append(results, [concept]);
            };
        };
        
        results
    };

    public func queryRelationships(
        relationships: [(Types.RelationshipId, Types.Relationship)],
        criteria: Types.RelationshipQuery
    ) : [Types.Relationship] {
        var results : [Types.Relationship] = [];
        
        for ((_, relationship) in relationships.vals()) {
            var matches = true;
            
            // Creator matching
            switch (criteria.creator) {
                case (?creator) {
                    if (relationship.creator.principalId != creator) {
                        matches := false;
                    };
                };
                case null {};
            };
            
            // Source concept matching
            switch (criteria.fromConceptId) {
                case (?id) {
                    if (relationship.fromConceptId != id) {
                        matches := false;
                    };
                };
                case null {};
            };
            
            // Target concept matching
            switch (criteria.toConceptId) {
                case (?id) {
                    if (relationship.toConceptId != id) {
                        matches := false;
                    };
                };
                case null {};
            };
            
            // Relationship type matching
            switch (criteria.relationshipTypeId) {
                case (?id) {
                    if (relationship.relationshipTypeId != id) {
                        matches := false;
                    };
                };
                case null {};
            };
            
            // Probability range matching
            switch (criteria.minProbability) {
                case (?min) {
                    if (not probabilityGreaterThanOrEqual(relationship.probability, min)) {
                        matches := false;
                    };
                };
                case null {};
            };
            
            switch (criteria.maxProbability) {
                case (?max) {
                    if (not probabilityLessThanOrEqual(relationship.probability, max)) {
                        matches := false;
                    };
                };
                case null {};
            };
            
            // Metadata matching
            for ((key, value) in criteria.metadata.vals()) {
                switch (Array.find<(Text, Text)>(relationship.metadata, func(entry) = entry.0 == key and entry.1 == value)) {
                    case null matches := false;
                    case (?_) {};
                };
            };
            
            if (matches) {
                results := Array.append(results, [relationship]);
            };
        };
        
        results
    };

    // Inference Functions
    public func inferRelationships(
        relationships: [(Types.RelationshipId, Types.Relationship)],
        relationshipTypes: [(Types.RelationshipTypeId, Types.RelationshipTypeDef)],
        inferenceParams: Types.InferenceQuery
    ) : [Types.InferredRelationship] {
        var results : [Types.InferredRelationship] = [];
        var visited : [(Types.ConceptId, Types.ConceptId)] = []; // (from, to) pairs
        
        // Helper to check if a path has been visited
        func isVisited(from: Types.ConceptId, to: Types.ConceptId) : Bool {
            Array.find<(Types.ConceptId, Types.ConceptId)>(
                visited,
                func(pair) = pair.0 == from and pair.1 == to
            ) != null
        };

        // Helper to multiply probabilities
        func multiplyProbabilities(p1: Types.Probability, p2: Types.Probability) : Types.Probability {
            {
                numerator = p1.numerator * p2.numerator;
                denominator = p1.denominator * p2.denominator;
            }
        };

        // Helper to check if probability meets threshold
        func meetsThreshold(p: Types.Probability, threshold: ?Types.Probability) : Bool {
            switch (threshold) {
                case null true;
                case (?min) probabilityGreaterThanOrEqual(p, min);
            };
        };

        // Helper to get relationship type properties
        func getTypeProperties(typeId: Types.RelationshipTypeId) : ?Types.RelationshipTypeProperties {
            switch (Array.find<(Types.RelationshipTypeId, Types.RelationshipTypeDef)>(
                relationshipTypes,
                func((id, _)) = id == typeId
            )) {
                case (?entry) ?entry.1.properties;
                case null null;
            };
        };

        // Get all direct relationships from the starting concept
        let directRelationships = Array.filter<(Types.RelationshipId, Types.Relationship)>(
            relationships,
            func((_, rel)) = 
                rel.fromConceptId == inferenceParams.startingConcept and
                (
                    switch (inferenceParams.relationshipType) {
                        case (?typeId) rel.relationshipTypeId == typeId;
                        case null rel.relationshipTypeId == Types.RELATIONSHIP_TYPE_IS_A;
                    }
                )
        );

        // Add direct relationships to results
        for ((id, rel) in directRelationships.vals()) {
            if (meetsThreshold(rel.probability, inferenceParams.minProbability)) {
                results := Array.append(results, [{
                    relationship = rel;
                    source = #Direct(id);
                }]);
                visited := Array.append(visited, [(rel.fromConceptId, rel.toConceptId)]);

                // Handle symmetric relationships
                switch (getTypeProperties(rel.relationshipTypeId)) {
                    case (?props) {
                        if (props.logical.symmetric) {
                            // Create symmetric relationship
                            let symRel : Types.Relationship = {
                                id = rel.id;  // Use same ID for symmetric pair
                                fromConceptId = rel.toConceptId;
                                toConceptId = rel.fromConceptId;
                                relationshipTypeId = rel.relationshipTypeId;
                                probability = rel.probability;
                                creator = rel.creator;  // Copy creator from original relationship
                                metadata = rel.metadata;
                            };
                            
                            if (not isVisited(symRel.fromConceptId, symRel.toConceptId)) {
                                results := Array.append(results, [{
                                    relationship = symRel;
                                    source = #Symmetric(id);
                                }]);
                                visited := Array.append(visited, [(symRel.fromConceptId, symRel.toConceptId)]);
                            };
                        };
                    };
                    case null {};
                };
            };
        };

        // Recursively find transitive relationships
        func findTransitive(
            currentId: Types.ConceptId,
            depth: Nat,
            currentProb: Types.Probability
        ) {
            // Check depth limit
            switch (inferenceParams.maxDepth) {
                case (?maxDepth) if (depth >= maxDepth) return;
                case null {};
            };

            // Get relationships where current concept is the source
            let nextRelationships = Array.filter<(Types.RelationshipId, Types.Relationship)>(
                relationships,
                func((_, rel)) = 
                    rel.fromConceptId == currentId and
                    (
                        switch (inferenceParams.relationshipType) {
                            case (?typeId) rel.relationshipTypeId == typeId;
                            case null rel.relationshipTypeId == Types.RELATIONSHIP_TYPE_IS_A;
                        }
                    )
            );

            // Process each relationship
            for ((id, rel) in nextRelationships.vals()) {
                let newProb = multiplyProbabilities(currentProb, rel.probability);
                
                // Only proceed if probability meets threshold
                if (meetsThreshold(newProb, inferenceParams.minProbability)) {
                    // Check if we've already visited this path
                    if (not isVisited(inferenceParams.startingConcept, rel.toConceptId)) {
                        // Create inferred relationship
                        let inferredRel : Types.Relationship = {
                            id = rel.id;  // We'll use the same ID for now
                            fromConceptId = inferenceParams.startingConcept;
                            toConceptId = rel.toConceptId;
                            relationshipTypeId = rel.relationshipTypeId;
                            probability = newProb;
                            creator = rel.creator;  // Copy creator from original relationship
                            metadata = rel.metadata;
                        };

                        results := Array.append(results, [{
                            relationship = inferredRel;
                            source = #Transitive({
                                first = id;
                                second = rel.id;
                                probability = newProb;
                            });
                        }]);

                        visited := Array.append(visited, [(inferenceParams.startingConcept, rel.toConceptId)]);

                        // Continue inference from this point
                        findTransitive(rel.toConceptId, depth + 1, newProb);
                    };
                };
            };
        };

        // Start transitive inference from each direct relationship
        for ((_, rel) in directRelationships.vals()) {
            // Only do transitive inference for transitive relationship types
            switch (getTypeProperties(rel.relationshipTypeId)) {
                case (?props) {
                    if (props.logical.transitive) {
                        findTransitive(rel.toConceptId, 1, rel.probability);
                    };
                };
                case null {};
            };
        };

        results
    };

    // Helper Functions
    private func textContains(text: Text, pattern: Text) : Bool {
        // Simple substring check
        let textIter = text.chars();
        let patternIter = pattern.chars();
        
        label search loop {
            let start = textIter.next();
            switch (start) {
                case null return false;
                case (?c) {
                    let patternCopy = pattern.chars();
                    switch (patternCopy.next()) {
                        case null return true;  // Empty pattern matches
                        case (?firstPattern) {
                            if (c == firstPattern) {
                                var matches = true;
                                label match loop {
                                    let nextPattern = patternCopy.next();
                                    switch (nextPattern) {
                                        case null return true;  // Matched all pattern chars
                                        case (?p) {
                                            let nextText = textIter.next();
                                            switch (nextText) {
                                                case null return false;
                                                case (?t) {
                                                    if (t != p) {
                                                        matches := false;
                                                        break match;
                                                    };
                                                };
                                            };
                                        };
                                    };
                                };
                                if (matches) return true;
                            };
                        };
                    };
                };
            };
        };
        false
    };

    private func probabilityGreaterThanOrEqual(p1: Types.Probability, p2: Types.Probability) : Bool {
        p1.numerator * p2.denominator >= p2.numerator * p1.denominator
    };

    private func probabilityLessThanOrEqual(p1: Types.Probability, p2: Types.Probability) : Bool {
        p1.numerator * p2.denominator <= p2.numerator * p1.denominator
    };
}
