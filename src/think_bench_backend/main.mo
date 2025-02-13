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
    private stable var stable_relationshipTypes : [(Types.RelationshipTypeId, Types.RelationshipTypeDef)] = [];
    
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
        stable_relationshipTypes.vals(),
        10,
        Nat.equal,
        Hash.hash
    );

    // System upgrade hooks
    system func preupgrade() {
        stable_concepts := Iter.toArray(concepts.entries());
        stable_relationships := Iter.toArray(relationships.entries());
        stable_relationshipTypes := Iter.toArray(relationshipTypes.entries());
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
            stable_relationshipTypes.vals(),
            stable_relationshipTypes.size(),
            Nat.equal,
            Hash.hash
        );

        // Clear stable state after successful reconstruction
        stable_concepts := [];
        stable_relationships := [];
        stable_relationshipTypes := [];
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
            nextConceptId
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
        metadata: ?[(Text, Text)]
    ) : async Types.Result<Types.RelationshipId, Types.Error> {
        let relationshipResult = Lib.createRelationship(
            Iter.toArray(concepts.entries()),
            fromConceptId,
            toConceptId,
            relationshipTypeId,
            probability,
            metadata,
            nextRelationshipId
        );

        switch (relationshipResult) {
            case (#ok(relationship)) {
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
            case (#err(error)) #err(error);
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
};
