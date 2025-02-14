import Types "Types";
import Lib "lib";
import Array "mo:base/Array";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Map "mo:base/HashMap";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Time "mo:base/Time";

actor ConceptBase {
    // Stable state for persistence
    private stable var stable_concepts : [(Types.ConceptId, Types.Concept)] = [];
    private stable var stable_relationships : [(Types.RelationshipId, Types.Relationship)] = [];
    private stable var stable_relationshipTypes : {
        entries: [(Types.RelationshipTypeId, {
            id: Types.RelationshipTypeId;
            name: Text;
            description: ?Text;
            properties: {
                logical: {
                    transitive: Bool;
                    symmetric: Bool;
                    reflexive: Bool;
                    irreflexive: Bool;
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
                validation: [Types.ValidationRule];
            };
            metadata: [(Text, Text)];
            status: {
                #ACTIVE;
                #DEPRECATED: {
                    replacedBy: ?Types.RelationshipTypeId;
                    reason: Text;
                };
            };
        })];
    } = { entries = [] };
    
    // ID counters
    private stable var nextConceptId : Nat = 0;
    private stable var nextRelationshipId : Nat = 0;
    private stable var nextRelationshipTypeId : Nat = 0;

    // Runtime state
    private var concepts = Map.fromIter<Types.ConceptId, Types.Concept>(
        stable_concepts.vals(),
        10,
        Nat.equal,
        Hash.hash
    );
    private var relationships = Map.fromIter<Types.RelationshipId, Types.Relationship>(
        stable_relationships.vals(),
        10,
        Nat.equal,
        Hash.hash
    );
    private var relationshipTypes = Map.fromIter<Types.RelationshipTypeId, Types.RelationshipTypeDef>(
        stable_relationshipTypes.entries.vals(),
        10,
        Nat.equal,
        Hash.hash
    );

    // System upgrade hooks
    system func preupgrade() {
        stable_concepts := Iter.toArray(concepts.entries());
        stable_relationships := Iter.toArray(relationships.entries());
        stable_relationshipTypes := {
            entries = Iter.toArray(relationshipTypes.entries());
        };
    };

    system func postupgrade() {
        concepts := Map.fromIter<Types.ConceptId, Types.Concept>(
            stable_concepts.vals(),
            stable_concepts.size(),
            Nat.equal,
            Hash.hash
        );
        relationships := Map.fromIter<Types.RelationshipId, Types.Relationship>(
            stable_relationships.vals(),
            stable_relationships.size(),
            Nat.equal,
            Hash.hash
        );
        relationshipTypes := Map.fromIter<Types.RelationshipTypeId, Types.RelationshipTypeDef>(
            stable_relationshipTypes.entries.vals(),
            stable_relationshipTypes.entries.size(),
            Nat.equal,
            Hash.hash
        );

        // Clear stable state after successful reconstruction
        stable_concepts := [];
        stable_relationships := [];
        stable_relationshipTypes := { entries = [] };
    };

    // Concept Management API
    public shared(msg) func createConcept(
        name: Text,
        description: ?Text,
        metadata: ?[(Text, Text)]
    ) : async Types.Result<Types.ConceptId, Types.Error> {
        let conceptResult = Lib.createConcept(
            Iter.toArray(concepts.entries()),
            name,
            description,
            metadata,
            nextConceptId,
            msg.caller
        );

        switch (conceptResult) {
            case (#ok(concept)) {
                concepts.put(concept.id, concept);
                nextConceptId += 1;
                #ok(concept.id)
            };
            case (#err(error)) #err(error);
        }
    };

    public shared(msg) func updateConcept(
        id: Types.ConceptId,
        name: ?Text,
        description: ?Text,
        metadata: ?[(Text, Text)]
    ) : async Types.Result<(), Types.Error> {
        switch (concepts.get(id)) {
            case (?concept) {
                // Check if caller is the creator
                switch (Lib.validateConceptModification(concept, msg.caller)) {
                    case (#err(e)) return #err(e);
                    case (#ok()) {};
                };

                let updatedConcept = {
                    concept with
                    name = Option.get(name, concept.name);
                    description = concept.description;
                    metadata = Option.get(metadata, concept.metadata);
                    modified = Time.now() : Time.Time;
                    creator = concept.creator;
                };
                concepts.put(id, updatedConcept);
                #ok()
            };
            case null #err(#NotFound("Concept not found"));
        }
    };

    // Query endpoints
    public query func getConcept(id: Types.ConceptId) : async Types.Result<Types.Concept, Types.Error> {
        switch (concepts.get(id)) {
            case (?concept) #ok(concept);
            case null #err(#NotFound("Concept not found"));
        }
    };

    public query func queryConcepts(criteria: Types.ConceptQuery) : async Types.QueryResult<Types.Concept> {
        let results = Lib.queryConcepts(Iter.toArray(concepts.entries()), criteria);
        #ok({
            items = results;
            total = results.size();
            page = 1;
            pageSize = results.size();
        })
    };

    // Relationship Management API
    public shared(msg) func assertRelationship(
        fromConceptId: Types.ConceptId,
        toConceptId: Types.ConceptId,
        relationshipTypeId: Types.RelationshipTypeId,
        probability: Types.Probability,
        confidence: Types.Confidence,
        metadata: ?[(Text, Text)]
    ) : async Types.Result<Types.RelationshipId, Types.Error> {
        // First validate the relationship type exists and is valid
        switch (relationshipTypes.get(relationshipTypeId)) {
            case null return #err(#NotFound("Relationship type not found"));
            case (?relType) {
                // Create the relationship
                let relationshipResult = Lib.createRelationship(
                    Iter.toArray(concepts.entries()),
                    fromConceptId,
                    toConceptId,
                    relationshipTypeId,
                    probability,
                    confidence,
                    metadata,
                    nextRelationshipId,
                    msg.caller
                );

                switch (relationshipResult) {
                    case (#err(error)) return #err(error);
                    case (#ok(relationship)) {
                        // Validate against type rules
                        switch (Lib.validateRelationshipAgainstType(relationship, relType)) {
                            case (#err(error)) return #err(error);
                            case (#ok()) {
                                // Update source concept's outgoing relationships
                                switch (concepts.get(fromConceptId)) {
                                    case (?concept) {
                                        let updatedConcept = {
                                            concept with
                                            outgoingRelationships = Array.append(concept.outgoingRelationships, [relationship.id])
                                        };
                                        concepts.put(fromConceptId, updatedConcept);
                                    };
                                    case null return #err(#NotFound("Source concept not found"));
                                };

                                // Update target concept's incoming relationships
                                switch (concepts.get(toConceptId)) {
                                    case (?concept) {
                                        let updatedConcept = {
                                            concept with
                                            incomingRelationships = Array.append(concept.incomingRelationships, [relationship.id])
                                        };
                                        concepts.put(toConceptId, updatedConcept);
                                    };
                                    case null return #err(#NotFound("Target concept not found"));
                                };

                                relationships.put(relationship.id, relationship);
                                nextRelationshipId += 1;
                                #ok(relationship.id)
                            };
                        }
                    };
                }
            };
        }
    };

    public shared(msg) func updateRelationship(
        id: Types.RelationshipId,
        probability: ?Types.Probability,
        metadata: ?[(Text, Text)]
    ) : async Types.Result<(), Types.Error> {
        switch (relationships.get(id)) {
            case (?relationship) {
                // Check if caller is the creator
                switch (Lib.validateRelationshipModification(relationship, msg.caller)) {
                    case (#err(e)) return #err(e);
                    case (#ok()) {};
                };

                let updatedRelationship = {
                    relationship with
                    probability = Option.get(probability, relationship.probability);
                    metadata = Option.get(metadata, relationship.metadata);
                };
                relationships.put(id, updatedRelationship);
                #ok()
            };
            case null #err(#NotFound("Relationship not found"));
        }
    };

    public query func getRelationship(id: Types.RelationshipId) : async Types.Result<Types.Relationship, Types.Error> {
        switch (relationships.get(id)) {
            case (?relationship) #ok(relationship);
            case null #err(#NotFound("Relationship not found"));
        }
    };

    public query func queryRelationships(criteria: Types.RelationshipQuery) : async Types.QueryResult<Types.Relationship> {
        let results = Lib.queryRelationships(Iter.toArray(relationships.entries()), criteria);
        #ok({
            items = results;
            total = results.size();
            page = 1;
            pageSize = results.size();
        })
    };

    // Relationship Type Management API
    public shared(msg) func createRelationshipType(
        name: Text,
        description: ?Text,
        properties: Types.RelationshipTypeProperties,
        metadata: [(Text, Text)]
    ) : async Types.Result<Types.RelationshipTypeId, Types.Error> {
        let typeResult = Lib.createRelationshipType(
            Iter.toArray(relationshipTypes.entries()),
            name,
            description,
            properties,
            metadata,
            nextRelationshipTypeId
        );

        switch (typeResult) {
            case (#ok(relType)) {
                relationshipTypes.put(relType.id, relType);
                nextRelationshipTypeId += 1;
                #ok(relType.id)
            };
            case (#err(error)) #err(error);
        }
    };

    public query func getRelationshipType(
        id: Types.RelationshipTypeId
    ) : async Types.Result<Types.RelationshipTypeDef, Types.Error> {
        switch (relationshipTypes.get(id)) {
            case (?relType) #ok(relType);
            case null #err(#NotFound("Relationship type not found"));
        }
    };

    public shared(msg) func deprecateRelationshipType(
        id: Types.RelationshipTypeId,
        replacedBy: ?Types.RelationshipTypeId,
        reason: Text
    ) : async Types.Result<(), Types.Error> {
        switch (relationshipTypes.get(id)) {
            case (?relType) {
                // Validate replacement type if provided
                switch (replacedBy) {
                    case (?replaceId) {
                        switch (relationshipTypes.get(replaceId)) {
                            case null {
                                return #err(#ValidationError({
                                    code = "INVALID_REPLACEMENT";
                                    message = "Replacement relationship type not found";
                                    details = ?{
                                        field = "replacedBy";
                                        constraint = "exists";
                                        value = Nat.toText(replaceId);
                                    };
                                }));
                            };
                            case (?_) {};
                        };
                    };
                    case null {};
                };

                // Update the type definition
                let updatedType = {
                    relType with
                    status = #DEPRECATED({
                        replacedBy = replacedBy;
                        reason = reason;
                    });
                };
                relationshipTypes.put(id, updatedType);
                #ok()
            };
            case null #err(#NotFound("Relationship type not found"));
        }
    };

    // Inference API
    public query func inferRelationships(
        params: Types.InferenceQuery
    ) : async Types.QueryResult<Types.InferredRelationship> {
        let results = Lib.inferRelationships(
            Iter.toArray(relationships.entries()),
            Iter.toArray(relationshipTypes.entries()),
            params
        );
        #ok({
            items = results;
            total = results.size();
            page = 1;
            pageSize = results.size();
        })
    };
};
