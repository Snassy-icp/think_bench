import Types "Types";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Error "mo:base/Error";

actor Test {
    // Reference to the main ConceptBase actor
    let conceptBase = actor("r7inp-6aaaa-aaaaa-aaabq-cai") : actor {
        createConcept : shared (Text, ?Text, ?[(Text, Text)]) -> async Types.Result<Types.ConceptId, Types.Error>;
        createRelationshipType : shared (Text, ?Text, Types.RelationshipTypeProperties, [(Text, Text)]) -> async Types.Result<Types.RelationshipTypeId, Types.Error>;
        assertRelationship : shared (Types.ConceptId, Types.ConceptId, Types.RelationshipTypeId, Types.Probability, ?[(Text, Text)]) -> async Types.Result<Types.RelationshipId, Types.Error>;
        inferRelationships : shared (Types.InferenceQuery) -> async Types.QueryResult<Types.InferredRelationship>;
    };

    // Test setup and execution
    public shared func runTests() : async Text {
        try {
            // 1. Create test concepts
            let animalId = switch(await conceptBase.createConcept("Animal", ?"Base category for animals", null)) {
                case (#ok(id)) id;
                case (#err(e)) return "Failed to create Animal concept: " # debug_show(e);
            };

            let mammalId = switch(await conceptBase.createConcept("Mammal", ?"Warm-blooded animals", null)) {
                case (#ok(id)) id;
                case (#err(e)) return "Failed to create Mammal concept: " # debug_show(e);
            };

            let dogId = switch(await conceptBase.createConcept("Dog", ?"Canine animal", null)) {
                case (#ok(id)) id;
                case (#err(e)) return "Failed to create Dog concept: " # debug_show(e);
            };

            let roverId = switch(await conceptBase.createConcept("Rover", ?"A specific dog", null)) {
                case (#ok(id)) id;
                case (#err(e)) return "Failed to create Rover concept: " # debug_show(e);
            };

            let spotId = switch(await conceptBase.createConcept("Spot", ?"Another specific dog", null)) {
                case (#ok(id)) id;
                case (#err(e)) return "Failed to create Spot concept: " # debug_show(e);
            };

            // Create concepts for parts and properties
            let heartId = switch(await conceptBase.createConcept("Heart", ?"Vital organ", null)) {
                case (#ok(id)) id;
                case (#err(e)) return "Failed to create Heart concept: " # debug_show(e);
            };

            let brainId = switch(await conceptBase.createConcept("Brain", ?"Neural organ", null)) {
                case (#ok(id)) id;
                case (#err(e)) return "Failed to create Brain concept: " # debug_show(e);
            };

            let tailId = switch(await conceptBase.createConcept("Tail", ?"Body appendage", null)) {
                case (#ok(id)) id;
                case (#err(e)) return "Failed to create Tail concept: " # debug_show(e);
            };

            let furId = switch(await conceptBase.createConcept("Fur", ?"Body covering", null)) {
                case (#ok(id)) id;
                case (#err(e)) return "Failed to create Fur concept: " # debug_show(e);
            };

            // 2. Create relationship types
            // SIBLING type (symmetric)
            let siblingProperties : Types.RelationshipTypeProperties = {
                logical = {
                    transitive = false;
                    symmetric = true;
                    reflexive = false;
                    irreflexive = true;
                };
                inheritance = {
                    inheritable = false;
                    probabilityMode = #MULTIPLY;
                };
                validation = [#NoSelfReference];
            };

            let siblingTypeId = switch(await conceptBase.createRelationshipType(
                "SIBLING",
                ?"Symmetric relationship between siblings",
                siblingProperties,
                []
            )) {
                case (#ok(id)) id;
                case (#err(e)) return "Failed to create SIBLING relationship type: " # debug_show(e);
            };

            // 3. Create IS-A relationships hierarchy
            // Rover IS-A Dog
            switch(await conceptBase.assertRelationship(
                roverId,
                dogId,
                Types.RELATIONSHIP_TYPE_IS_A,
                { numerator = 1; denominator = 1 },
                null
            )) {
                case (#err(e)) return "Failed to create Rover IS-A Dog relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // Dog IS-A Mammal
            switch(await conceptBase.assertRelationship(
                dogId,
                mammalId,
                Types.RELATIONSHIP_TYPE_IS_A,
                { numerator = 1; denominator = 1 },
                null
            )) {
                case (#err(e)) return "Failed to create Dog IS-A Mammal relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // Mammal IS-A Animal
            switch(await conceptBase.assertRelationship(
                mammalId,
                animalId,
                Types.RELATIONSHIP_TYPE_IS_A,
                { numerator = 1; denominator = 1 },
                null
            )) {
                case (#err(e)) return "Failed to create Mammal IS-A Animal relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // Spot IS-A Dog
            switch(await conceptBase.assertRelationship(
                spotId,
                dogId,
                Types.RELATIONSHIP_TYPE_IS_A,
                { numerator = 1; denominator = 1 },
                null
            )) {
                case (#err(e)) return "Failed to create Spot IS-A Dog relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // 4. Create HAS-A relationships for inheritance
            // Animal HAS-A Brain (high probability)
            switch(await conceptBase.assertRelationship(
                animalId,
                brainId,
                Types.RELATIONSHIP_TYPE_HAS_A,
                { numerator = 999; denominator = 1000 },
                null
            )) {
                case (#err(e)) return "Failed to create Animal HAS-A Brain relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // Mammal HAS-A Heart (certain)
            switch(await conceptBase.assertRelationship(
                mammalId,
                heartId,
                Types.RELATIONSHIP_TYPE_HAS_A,
                { numerator = 1; denominator = 1 },
                null
            )) {
                case (#err(e)) return "Failed to create Mammal HAS-A Heart relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // Dog HAS-A Tail (high probability)
            switch(await conceptBase.assertRelationship(
                dogId,
                tailId,
                Types.RELATIONSHIP_TYPE_HAS_A,
                { numerator = 95; denominator = 100 },
                null
            )) {
                case (#err(e)) return "Failed to create Dog HAS-A Tail relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // Dog HAS-A Fur (high probability)
            switch(await conceptBase.assertRelationship(
                dogId,
                furId,
                Types.RELATIONSHIP_TYPE_HAS_A,
                { numerator = 98; denominator = 100 },
                null
            )) {
                case (#err(e)) return "Failed to create Dog HAS-A Fur relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // 5. Create sibling relationship
            // Rover and Spot are siblings
            switch(await conceptBase.assertRelationship(
                roverId,
                spotId,
                siblingTypeId,
                { numerator = 95; denominator = 100 },
                null
            )) {
                case (#err(e)) return "Failed to create Rover SIBLING Spot relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // 6. Test transitive IS-A inference
            let roverInference = await conceptBase.inferRelationships({
                startingConcept = roverId;
                relationshipType = ?Types.RELATIONSHIP_TYPE_IS_A;
                maxDepth = ?3;
                minProbability = null;
            });

            Debug.print("Rover IS-A inference results:");
            switch(roverInference) {
                case (#ok(results)) {
                    for (inferred in results.items.vals()) {
                        Debug.print("- " # debug_show(inferred));
                    };
                };
                case (#err(e)) return "Failed to run IS-A inference: " # debug_show(e);
            };

            // 7. Test HAS-A inheritance through IS-A
            let roverHasA = await conceptBase.inferRelationships({
                startingConcept = roverId;
                relationshipType = ?Types.RELATIONSHIP_TYPE_HAS_A;
                maxDepth = ?3;
                minProbability = null;
            });

            Debug.print("Rover HAS-A inheritance results:");
            switch(roverHasA) {
                case (#ok(results)) {
                    for (inferred in results.items.vals()) {
                        Debug.print("- " # debug_show(inferred));
                    };
                };
                case (#err(e)) return "Failed to run HAS-A inference: " # debug_show(e);
            };

            // 8. Test symmetric inference
            let spotSiblings = await conceptBase.inferRelationships({
                startingConcept = spotId;
                relationshipType = ?siblingTypeId;
                maxDepth = ?1;
                minProbability = null;
            });

            Debug.print("Spot SIBLING inference results:");
            switch(spotSiblings) {
                case (#ok(results)) {
                    for (inferred in results.items.vals()) {
                        Debug.print("- " # debug_show(inferred));
                    };
                };
                case (#err(e)) return "Failed to run SIBLING inference: " # debug_show(e);
            };

            return "All tests completed successfully!";
        } catch (error) {
            return "Test failed with error: " # Error.message(error);
        };
    };
} 