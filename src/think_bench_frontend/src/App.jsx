import React, { useState, useEffect } from 'react';
import { think_bench_backend } from '../../declarations/think_bench_backend';
import './App.scss';

function App() {
  const [concepts, setConcepts] = useState([]);
  const [selectedConcept, setSelectedConcept] = useState(null);
  const [relationships, setRelationships] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [newConceptData, setNewConceptData] = useState({
    name: '',
    description: '',
  });
  const [newRelationshipData, setNewRelationshipData] = useState({
    targetConceptId: '',
    relationshipTypeId: '0', // Default to IS-A
    probability: { numerator: 1, denominator: 1 }
  });

  // Relationship type constants
  const RELATIONSHIP_TYPES = {
    IS_A: '0',
    HAS_A: '1',
    PART_OF: '2',
    PROPERTY_OF: '3'
  };

  // Load concepts on mount
  useEffect(() => {
    initializeRelationshipTypes();
    loadConcepts();
  }, []);

  // Initialize basic relationship types
  const initializeRelationshipTypes = async () => {
    try {
      // Define the basic relationship types
      const basicTypes = [
        {
          name: "IS-A",
          description: ["Basic inheritance relationship"],
          properties: {
            logical: {
              transitive: true,
              symmetric: false,
              reflexive: false,
              irreflexive: true,
            },
            inheritance: {
              inheritable: true,
              probabilityMode: { 'MULTIPLY': null },
            },
            validation: [{ 'NoSelfReference': null }],
          },
          metadata: [],
        },
        {
          name: "HAS-A",
          description: ["Composition relationship"],
          properties: {
            logical: {
              transitive: false,
              symmetric: false,
              reflexive: false,
              irreflexive: true,
            },
            inheritance: {
              inheritable: true,
              probabilityMode: { 'MULTIPLY': null },
            },
            validation: [{ 'NoSelfReference': null }],
          },
          metadata: [],
        },
        {
          name: "PART-OF",
          description: ["Part-whole relationship"],
          properties: {
            logical: {
              transitive: true,
              symmetric: false,
              reflexive: false,
              irreflexive: true,
            },
            inheritance: {
              inheritable: false,
              probabilityMode: { 'MULTIPLY': null },
            },
            validation: [{ 'NoSelfReference': null }],
          },
          metadata: [],
        },
        {
          name: "PROPERTY-OF",
          description: ["Property relationship"],
          properties: {
            logical: {
              transitive: false,
              symmetric: false,
              reflexive: false,
              irreflexive: true,
            },
            inheritance: {
              inheritable: true,
              probabilityMode: { 'MULTIPLY': null },
            },
            validation: [{ 'NoSelfReference': null }],
          },
          metadata: [],
        },
      ];

      // Create each relationship type if it doesn't exist
      for (const type of basicTypes) {
        try {
          await think_bench_backend.createRelationshipType(
            type.name,
            type.description,
            type.properties,
            type.metadata
          );
        } catch (error) {
          // Ignore errors - type might already exist
          console.log(`Note: ${type.name} type might already exist`);
        }
      }
    } catch (err) {
      console.error('Error initializing relationship types:', err);
    }
  };

  // Load concepts from backend
  const loadConcepts = async () => {
    try {
      setLoading(true);
      const result = await think_bench_backend.queryConcepts({
        namePattern: [],  // Optional: none
        metadata: [],     // Empty vec
        hasInstances: [], // Optional: none
        isInstance: [],   // Optional: none
      });
      if ('ok' in result) {
        setConcepts(result.ok.items);
      } else {
        setError('Failed to load concepts');
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  // Create new concept
  const createConcept = async (e) => {
    e.preventDefault();
    try {
      setLoading(true);
      const result = await think_bench_backend.createConcept(
        newConceptData.name,
        newConceptData.description ? [newConceptData.description] : [], // Optional text
        []  // Optional metadata: none
      );
      if ('ok' in result) {
        setNewConceptData({ name: '', description: '' });
        loadConcepts();
      } else {
        setError('Failed to create concept');
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  // Load relationships for a concept
  const loadRelationships = async (conceptId) => {
    try {
      setLoading(true);
      // Get outgoing relationships (where this concept is the source)
      const outgoingResult = await think_bench_backend.inferRelationships({
        startingConcept: conceptId,
        relationshipType: [],  // Optional: none
        maxDepth: [3],        // Optional: some(3)
        minProbability: [],   // Optional: none
      });

      // Get incoming relationships (where this concept is the target)
      const incomingResult = await think_bench_backend.queryRelationships({
        fromConceptId: [],           // Optional: none
        toConceptId: [conceptId],    // This concept as target
        relationshipTypeId: [],      // Optional: none
        minProbability: [],          // Optional: none
        maxProbability: [],          // Optional: none
        metadata: [],                // Empty metadata constraints
      });
      
      if ('ok' in outgoingResult && 'ok' in incomingResult) {
        // Combine both sets of relationships
        const allRelationships = [
          ...outgoingResult.ok.items,
          // Convert direct relationships to the same format as inferred ones
          ...incomingResult.ok.items.map(rel => ({
            relationship: rel,
            source: { tag: 'Direct', value: rel.id }
          }))
        ];
        setRelationships(allRelationships);
      } else {
        setError('Failed to load relationships');
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  // Handle concept selection
  const handleConceptSelect = (concept) => {
    setSelectedConcept({
      ...concept,
      id: concept.id.toString()  // Store ID as string
    });
    loadRelationships(concept.id);  // Motoko function expects BigInt
  };

  // Create new relationship
  const createRelationship = async (e) => {
    e.preventDefault();
    if (!selectedConcept) return;

    try {
      setLoading(true);
      setError(null); // Clear any previous errors

      // Validate probability values
      const { numerator, denominator } = newRelationshipData.probability;
      if (denominator <= 0 || numerator > denominator) {
        setError('Invalid probability: numerator must be less than or equal to denominator, and denominator must be positive');
        return;
      }

      const result = await think_bench_backend.assertRelationship(
        BigInt(selectedConcept.id),
        BigInt(newRelationshipData.targetConceptId),
        BigInt(newRelationshipData.relationshipTypeId),
        {
          numerator: Number(numerator),
          denominator: Number(denominator)
        },
        [] // Optional metadata: none
      );
      
      if ('ok' in result) {
        // Reset form and reload relationships
        setNewRelationshipData({
          targetConceptId: '',
          relationshipTypeId: '0',
          probability: { numerator: 1, denominator: 1 }
        });
        await loadRelationships(BigInt(selectedConcept.id));
      } else if ('err' in result) {
        // Handle specific error messages from the backend
        const errorMessage = result.err.ValidationError?.message || 
                           result.err.NotFound || 
                           result.err.InvalidOperation ||
                           'Failed to create relationship';
        setError(errorMessage);
      }
    } catch (err) {
      setError(err.message || 'An unexpected error occurred');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="app">
      <header className="header">
        <h1>Think Bench</h1>
        <p>A Concept Base for Logical Reasoning</p>
      </header>

      <main className="main">
        <div className="sidebar">
          <div className="create-concept">
            <h2>Create New Concept</h2>
            <form onSubmit={createConcept}>
              <input
                type="text"
                placeholder="Concept Name"
                value={newConceptData.name}
                onChange={(e) => setNewConceptData({ ...newConceptData, name: e.target.value })}
                required
              />
              <textarea
                placeholder="Description (optional)"
                value={newConceptData.description}
                onChange={(e) => setNewConceptData({ ...newConceptData, description: e.target.value })}
              />
              <button type="submit" disabled={loading}>
                {loading ? 'Creating...' : 'Create Concept'}
              </button>
            </form>
          </div>

          <div className="concepts-list">
            <h2>Concepts</h2>
            {loading && <div className="loading">Loading...</div>}
            {error && <div className="error">{error}</div>}
            <ul>
              {concepts.map((concept) => (
                <li
                  key={concept.id.toString()}
                  className={selectedConcept?.id === concept.id.toString() ? 'selected' : ''}
                  onClick={() => handleConceptSelect(concept)}
                >
                  <span className="concept-name">{concept.name}</span>
                  {concept.description && (
                    <span className="concept-description">{concept.description}</span>
                  )}
                </li>
              ))}
            </ul>
          </div>
        </div>

        <div className="content">
          {selectedConcept ? (
            <div className="concept-details">
              <h2>{selectedConcept.name}</h2>
              {selectedConcept.description && <p>{selectedConcept.description}</p>}

              <div className="create-relationship">
                <h3>Create New Relationship</h3>
                <form onSubmit={createRelationship}>
                  <select
                    value={newRelationshipData.targetConceptId}
                    onChange={(e) => setNewRelationshipData({
                      ...newRelationshipData,
                      targetConceptId: e.target.value  // Store as string
                    })}
                    required
                  >
                    <option value="">Select Target Concept</option>
                    {concepts
                      .filter(c => c.id.toString() !== selectedConcept.id)
                      .map(concept => (
                        <option key={concept.id.toString()} value={concept.id.toString()}>
                          {concept.name}
                        </option>
                      ))
                    }
                  </select>

                  <select
                    value={newRelationshipData.relationshipTypeId}
                    onChange={(e) => setNewRelationshipData({
                      ...newRelationshipData,
                      relationshipTypeId: e.target.value
                    })}
                    required
                  >
                    <option value={RELATIONSHIP_TYPES.IS_A}>IS-A</option>
                    <option value={RELATIONSHIP_TYPES.HAS_A}>HAS-A</option>
                    <option value={RELATIONSHIP_TYPES.PART_OF}>PART-OF</option>
                    <option value={RELATIONSHIP_TYPES.PROPERTY_OF}>PROPERTY-OF</option>
                  </select>

                  <div className="probability-input">
                    <input
                      type="number"
                      min="0"
                      max="999"
                      value={newRelationshipData.probability.numerator}
                      onChange={(e) => setNewRelationshipData({
                        ...newRelationshipData,
                        probability: {
                          ...newRelationshipData.probability,
                          numerator: parseInt(e.target.value, 10)
                        }
                      })}
                      required
                    />
                    <span>/</span>
                    <input
                      type="number"
                      min="1"
                      max="999"
                      value={newRelationshipData.probability.denominator}
                      onChange={(e) => setNewRelationshipData({
                        ...newRelationshipData,
                        probability: {
                          ...newRelationshipData.probability,
                          denominator: parseInt(e.target.value, 10)
                        }
                      })}
                      required
                    />
                  </div>

                  <button type="submit" disabled={loading}>
                    {loading ? 'Creating...' : 'Create Relationship'}
                  </button>
                </form>
              </div>

              <div className="relationships">
                <h3>Relationships</h3>
                {loading && <div className="loading">Loading relationships...</div>}
                <ul>
                  {relationships.map((rel) => (
                    <li key={rel.relationship.id} className="relationship">
                      <div className="relationship-type">
                        {getRelationshipTypeName(rel.relationship.relationshipTypeId)}
                      </div>
                      <div className="relationship-target">
                        {getConceptName(concepts, rel.relationship.toConceptId)}
                      </div>
                      <div className="relationship-probability">
                        {formatProbability(rel.relationship.probability)}
                      </div>
                      {rel.source.tag === 'Transitive' && (
                        <div className="inference-info">
                          (Inferred through transitivity)
                        </div>
                      )}
                      {rel.source.tag === 'Symmetric' && (
                        <div className="inference-info">
                          (Inferred through symmetry)
                        </div>
                      )}
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          ) : (
            <div className="no-selection">
              <p>Select a concept to view details</p>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}

// Helper functions
function getRelationshipTypeName(typeId) {
  const types = {
    0: 'IS-A',
    1: 'HAS-A',
    2: 'PART-OF',
    3: 'PROPERTY-OF',
  };
  return types[Number(typeId)] || `Type ${typeId}`;
}

function getConceptName(concepts, conceptId) {
  const concept = concepts.find(c => c.id.toString() === conceptId.toString());
  return concept ? concept.name : `Concept ${conceptId}`;
}

function formatProbability(prob) {
  return `${prob.numerator}/${prob.denominator}`;
}

export default App;
