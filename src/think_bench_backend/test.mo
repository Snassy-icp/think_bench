import Types "Types";
import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Error "mo:base/Error";

actor Test {
    // Reference to the main ConceptBase actor
    let conceptBase = actor("bd3sg-teaaa-aaaaa-qaaba-cai") : actor {
        createConcept : (name: Text, description: ?Text, metadata: ?[(Text, Text)]) -> async Types.Result<Types.ConceptId, Types.Error>;
        createRelationshipType : (name: Text, description: ?Text, properties: Types.RelationshipTypeProperties, metadata: [(Text, Text)]) -> async Types.Result<Types.RelationshipTypeId, Types.Error>;
        assertRelationship : (fromConceptId: Types.ConceptId, toConceptId: Types.ConceptId, relationshipTypeId: Types.RelationshipTypeId, probability: Types.Probability, confidence: Types.Confidence, metadata: ?[(Text, Text)]) -> async Types.Result<Types.RelationshipId, Types.Error>;
        inferRelationships : (params: Types.InferenceQuery) -> async Types.QueryResult<Types.InferredRelationship>;
    };

    // Test setup and execution
    public shared func runTests() : async Text {
        try {
            // Run basic tests
            let basicResult = await testBasic();
            if (Text.startsWith(basicResult, #text("Failed")) or Text.startsWith(basicResult, #text("Test failed"))) {
                return basicResult;
            };

            // Run confidence tests
            let confidenceResult = await testConfidence();
            if (Text.startsWith(confidenceResult, #text("Failed")) or Text.startsWith(confidenceResult, #text("Test failed"))) {
                return confidenceResult;
            };

            return "All tests completed successfully!";
        } catch (error) {
            return "Test failed with error: " # Error.message(error);
        };
    };

    // Test confidence score handling
    public shared func testConfidence() : async Text {
        try {
            // Test confidence score handling
            let catId = switch(await conceptBase.createConcept("Cat", ?"Feline animal", ?[])) {
                case (#ok(id)) id;
                case (#err(e)) return "Failed to create Cat concept: " # debug_show(e);
            };

            let mouseId = switch(await conceptBase.createConcept("Mouse", ?"Small rodent", ?[])) {
                case (#ok(id)) id;
                case (#err(e)) return "Failed to create Mouse concept: " # debug_show(e);
            };

            // High confidence relationship
            switch(await conceptBase.assertRelationship(
                catId,
                mouseId,
                Types.RELATIONSHIP_TYPE_HAS_A,
                { numerator = 95; denominator = 100 },  // High probability of cats hunting mice
                { numerator = 99; denominator = 100 },  // High confidence in this knowledge
                ?[]
            )) {
                case (#err(e)) return "Failed to create high-confidence relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // Low confidence relationship
            switch(await conceptBase.assertRelationship(
                mouseId,
                catId,
                Types.RELATIONSHIP_TYPE_HAS_A,
                { numerator = 1; denominator = 100 },   // Low probability
                { numerator = 30; denominator = 100 },  // Low confidence
                ?[]
            )) {
                case (#err(e)) return "Failed to create low-confidence relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // Test confidence threshold in queries
            let highConfQuery = await conceptBase.inferRelationships({
                startingConcept = catId;
                relationshipType = ?Types.RELATIONSHIP_TYPE_HAS_A;
                maxDepth = ?1;
                minProbability = ?{ numerator = 50; denominator = 100 };
                minConfidence = ?{ numerator = 90; denominator = 100 };
            });

            Debug.print("High confidence query results:");
            switch(highConfQuery) {
                case (#ok(results)) {
                    if (results.items.size() != 1) {
                        return "Expected 1 high-confidence result, got: " # debug_show(results.items.size());
                    };
                    for (inferred in results.items.vals()) {
                        Debug.print("- " # debug_show(inferred));
                    };
                };
                case (#err(e)) return "Failed to run high-confidence query: " # debug_show(e);
            };

            // Test low confidence threshold (should include both relationships)
            let lowConfQuery = await conceptBase.inferRelationships({
                startingConcept = catId;
                relationshipType = ?Types.RELATIONSHIP_TYPE_HAS_A;
                maxDepth = ?1;
                minProbability = ?{ numerator = 0; denominator = 100 };
                minConfidence = ?{ numerator = 20; denominator = 100 };
            });

            Debug.print("Low confidence query results:");
            switch(lowConfQuery) {
                case (#ok(results)) {
                    if (results.items.size() != 2) {
                        return "Expected 2 low-confidence results, got: " # debug_show(results.items.size());
                    };
                    for (inferred in results.items.vals()) {
                        Debug.print("- " # debug_show(inferred));
                    };
                };
                case (#err(e)) return "Failed to run low-confidence query: " # debug_show(e);
            };

            return "Confidence tests completed successfully!";
        } catch (error) {
            return "Confidence tests failed with error: " # Error.message(error);
        };
    };

    public shared func testBasic() : async Text {
        try {
            // 0. Initialize basic relationship types
            let isAProperties : Types.RelationshipTypeProperties = {
                logical = {
                    transitive = true;
                    symmetric = false;
                    reflexive = false;
                    irreflexive = true;
                };
                inheritance = {
                    inheritable = true;
                    probabilityMode = #MULTIPLY;
                };
                validation = [#NoSelfReference];
            };

            let hasAProperties : Types.RelationshipTypeProperties = {
                logical = {
                    transitive = false;
                    symmetric = false;
                    reflexive = false;
                    irreflexive = true;
                };
                inheritance = {
                    inheritable = true;
                    probabilityMode = #MULTIPLY;
                };
                validation = [#NoSelfReference];
            };

            // Create IS-A type
            let isATypeId = switch(await conceptBase.createRelationshipType(
                "IS-A",
                ?"Basic inheritance relationship",
                isAProperties,
                []
            )) {
                case (#ok(id)) id;
                case (#err(e)) return "Failed to create IS-A relationship type: " # debug_show(e);
            };

            // Create HAS-A type
            let hasATypeId = switch(await conceptBase.createRelationshipType(
                "HAS-A",
                ?"Composition relationship",
                hasAProperties,
                []
            )) {
                case (#ok(id)) id;
                case (#err(e)) return "Failed to create HAS-A relationship type: " # debug_show(e);
            };

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
                isATypeId,
                { numerator = 1; denominator = 1 },
                { numerator = 1; denominator = 1 },  // High confidence in IS-A relationships
                ?[]
            )) {
                case (#err(e)) return "Failed to create Rover IS-A Dog relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // Dog IS-A Mammal
            switch(await conceptBase.assertRelationship(
                dogId,
                mammalId,
                isATypeId,
                { numerator = 1; denominator = 1 },
                { numerator = 1; denominator = 1 },  // High confidence in IS-A relationships
                ?[]
            )) {
                case (#err(e)) return "Failed to create Dog IS-A Mammal relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // Mammal IS-A Animal
            switch(await conceptBase.assertRelationship(
                mammalId,
                animalId,
                isATypeId,
                { numerator = 1; denominator = 1 },
                { numerator = 1; denominator = 1 },  // High confidence in IS-A relationships
                ?[]
            )) {
                case (#err(e)) return "Failed to create Mammal IS-A Animal relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // Spot IS-A Dog
            switch(await conceptBase.assertRelationship(
                spotId,
                dogId,
                isATypeId,
                { numerator = 1; denominator = 1 },
                { numerator = 1; denominator = 1 },  // High confidence in IS-A relationships
                ?[]
            )) {
                case (#err(e)) return "Failed to create Spot IS-A Dog relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // 4. Create HAS-A relationships for inheritance
            // Animal HAS-A Brain (high probability)
            switch(await conceptBase.assertRelationship(
                animalId,
                brainId,
                hasATypeId,
                { numerator = 999; denominator = 1000 },
                { numerator = 95; denominator = 100 },  // High confidence in anatomical knowledge
                ?[]
            )) {
                case (#err(e)) return "Failed to create Animal HAS-A Brain relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // Mammal HAS-A Heart (certain)
            switch(await conceptBase.assertRelationship(
                mammalId,
                heartId,
                hasATypeId,
                { numerator = 1; denominator = 1 },
                { numerator = 98; denominator = 100 },  // High confidence in anatomical knowledge
                ?[]
            )) {
                case (#err(e)) return "Failed to create Mammal HAS-A Heart relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // Dog HAS-A Tail (high probability)
            switch(await conceptBase.assertRelationship(
                dogId,
                tailId,
                hasATypeId,
                { numerator = 95; denominator = 100 },
                { numerator = 90; denominator = 100 },  // Good confidence in general dog traits
                ?[]
            )) {
                case (#err(e)) return "Failed to create Dog HAS-A Tail relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // Dog HAS-A Fur (high probability)
            switch(await conceptBase.assertRelationship(
                dogId,
                furId,
                hasATypeId,
                { numerator = 98; denominator = 100 },
                { numerator = 95; denominator = 100 },  // High confidence in general dog traits
                ?[]
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
                { numerator = 80; denominator = 100 },  // Moderate confidence in sibling relationship
                ?[]
            )) {
                case (#err(e)) return "Failed to create Rover SIBLING Spot relationship: " # debug_show(e);
                case (#ok(_)) {};
            };

            // 6. Test transitive IS-A inference
            let roverInference = await conceptBase.inferRelationships({
                startingConcept = roverId;
                relationshipType = ?isATypeId;
                maxDepth = ?3;
                minProbability = ?{ numerator = 1; denominator = 1 };
                minConfidence = ?{ numerator = 90; denominator = 100 };
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
                relationshipType = ?hasATypeId;
                maxDepth = ?3;
                minProbability = ?{ numerator = 50; denominator = 100 };
                minConfidence = ?{ numerator = 80; denominator = 100 };
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
                minProbability = ?{ numerator = 90; denominator = 100 };
                minConfidence = ?{ numerator = 75; denominator = 100 };
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

            return "Basic tests completed successfully!";
        } catch (error) {
            return "Test failed with error: " # Error.message(error);
        };
    };
} 