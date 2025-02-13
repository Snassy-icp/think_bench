import Types "Types";
import Array "mo:base/Array";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Time "mo:base/Time";

module {
    // Concept Management
    public func createConcept(
        concepts: [(Types.ConceptId, Types.Concept)],
        name: Text,
        description: ?Text,
        metadata: ?[(Text, Text)],
        nextId: Nat
    ) : Types.Result<Types.Concept, Types.Error> {
        let concept : Types.Concept = {
            id = nextId;
            name = name;
            description = description;
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

    // Relationship Management
    public func createRelationship(
        concepts: [(Types.ConceptId, Types.Concept)],
        fromConceptId: Types.ConceptId,
        toConceptId: Types.ConceptId,
        relationshipTypeId: Types.RelationshipTypeId,
        probability: Types.Probability,
        metadata: ?[(Text, Text)],
        nextId: Nat
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
            return #err(#ValidationError("Invalid probability"));
        };

        let relationship : Types.Relationship = {
            id = nextId;
            fromConceptId = fromConceptId;
            toConceptId = toConceptId;
            relationshipTypeId = relationshipTypeId;
            probability = probability;
            metadata = Option.get(metadata, []);
        };
        #ok(relationship)
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

    // Query Functions
    public func queryConcepts(
        concepts: [(Types.ConceptId, Types.Concept)],
        criteria: Types.ConceptQuery
    ) : [Types.Concept] {
        var results : [Types.Concept] = [];
        
        for ((_, concept) in concepts.vals()) {
            var matches = true;
            
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
