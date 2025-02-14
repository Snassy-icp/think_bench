import React, { useState, useEffect } from 'react';
import { think_bench_backend, createActor as createBackendActor, canisterId as backendCanisterId } from 'declarations/think_bench_backend';
import { AuthClient } from '@dfinity/auth-client';
import { Actor, HttpAgent } from '@dfinity/agent';
import './App.scss';

// Constants for mainnet deployment
const IDENTITY_PROVIDER = 'https://identity.ic0.app';

function App() {
  const [authClient, setAuthClient] = useState(null);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [identity, setIdentity] = useState(null);
  const [principal, setPrincipal] = useState(null);
  const [actor, setActor] = useState(createBackendActor(backendCanisterId));
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
    probability: { numerator: 1, denominator: 1 },
    confidence: { numerator: 1, denominator: 1 }  // Add default confidence
  });

  // Relationship type constants
  const RELATIONSHIP_TYPES = {
    IS_A: '0',
    HAS_A: '1',
    PART_OF: '2',
    PROPERTY_OF: '3'
  };

  // Initialize auth client
  useEffect(() => {
    initAuth();
  }, []);

  const initAuth = async () => {
    try {
      const client = await AuthClient.create();
      const isAuthenticated = await client.isAuthenticated();
      setAuthClient(client);
      setIsAuthenticated(isAuthenticated);

      if (isAuthenticated) {
        const identity = client.getIdentity();
        setIdentity(identity);
        setPrincipal(identity.getPrincipal().toString());
        // Create new actor with identity
        const agent = new HttpAgent({ identity });
        agent.fetchRootKey();  // Needed for local development
        const backendActor = createBackendActor(backendCanisterId, { agentOptions: { identity } }); 
        setActor(backendActor);
      }
    } catch (error) {
      console.error('Error initializing auth:', error);
    }
  };

  const login = async () => {
    try {
      await authClient?.login({
        identityProvider: IDENTITY_PROVIDER,
        onSuccess: async () => {
          setIsAuthenticated(true);
          const identity = authClient.getIdentity();
          setIdentity(identity);
          setPrincipal(identity.getPrincipal().toString());
          // Create new actor with identity
          const agent = new HttpAgent({ identity });
          agent.fetchRootKey();  // Needed for local development
          const backendActor = createBackendActor(backendCanisterId, { agentOptions: { identity } }); 
          setActor(backendActor);
          // Load concepts after successful login
          loadConcepts();
        },
      });
    } catch (error) {
      console.error('Login failed:', error);
    }
  };

  const logout = async () => {
    try {
      await authClient?.logout();
      setIsAuthenticated(false);
      setIdentity(null);
      setPrincipal(null);
      // Clear application state
      setConcepts([]);
      setSelectedConcept(null);
      setRelationships([]);
    } catch (error) {
      console.error('Logout failed:', error);
    }
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
          await actor.createRelationshipType(
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
      const result = await actor.queryConcepts({
        namePattern: [],  // Optional: none
        metadata: [],     // Empty vec
        hasInstances: [], // Optional: none
        isInstance: [],   // Optional: none
        creator: []       // Optional: none, include all creators
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
      const result = await actor.createConcept(
        newConceptData.name,
        newConceptData.description ? [newConceptData.description] : [],
        []
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
      const outgoingResult = await actor.inferRelationships({
        startingConcept: conceptId,
        relationshipType: [],
        maxDepth: [3],
        minProbability: [],
        minConfidence: []  // Add empty optional for minConfidence
      });

      // Get incoming relationships (where this concept is the target)
      const incomingResult = await actor.queryRelationships({
        fromConceptId: [],
        toConceptId: [conceptId],
        relationshipTypeId: [],
        minProbability: [],
        maxProbability: [],
        metadata: [],
        creator: []  // Optional: none, include all creators
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

      const result = await actor.assertRelationship(
        BigInt(selectedConcept.id),
        BigInt(newRelationshipData.targetConceptId),
        BigInt(newRelationshipData.relationshipTypeId),
        {
          numerator: Number(newRelationshipData.probability.numerator),
          denominator: Number(newRelationshipData.probability.denominator)
        },
        {
          numerator: Number(newRelationshipData.confidence.numerator),
          denominator: Number(newRelationshipData.confidence.denominator)
        },
        [] // Optional metadata: none
      );
      
      if ('ok' in result) {
        // Reset form and reload relationships
        setNewRelationshipData({
          targetConceptId: '',
          relationshipTypeId: '0',
          probability: { numerator: 1, denominator: 1 },
          confidence: { numerator: 1, denominator: 1 }
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
        <div className="header-content">
          <div className="header-title">
            <h1>Think Bench</h1>
            <p>A Concept Base for Logical Reasoning</p>
          </div>
          <div className="auth-section">
            {isAuthenticated ? (
              <div className="user-info">
                <span className="principal">Principal: {principal?.slice(0, 10)}...</span>
                <button onClick={logout} className="auth-button">Logout</button>
              </div>
            ) : (
              <button onClick={login} className="auth-button">Login with Internet Identity</button>
            )}
          </div>
        </div>
      </header>

      <main className="main">
        {isAuthenticated ? (
          <>
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
                      <span className="concept-creator">Created by: {concept.creator.principalId.toString().slice(0, 10)}...</span>
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
                  <div className="concept-creator-details">
                    Created by: {selectedConcept.creator.principalId.toString().slice(0, 10)}...
                  </div>

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
                        <label>Probability:</label>
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

                      <div className="confidence-input">
                        <label>Confidence:</label>
                        <input
                          type="number"
                          min="0"
                          max="999"
                          value={newRelationshipData.confidence.numerator}
                          onChange={(e) => setNewRelationshipData({
                            ...newRelationshipData,
                            confidence: {
                              ...newRelationshipData.confidence,
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
                          value={newRelationshipData.confidence.denominator}
                          onChange={(e) => setNewRelationshipData({
                            ...newRelationshipData,
                            confidence: {
                              ...newRelationshipData.confidence,
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
                      {relationships.map((rel) => {
                        const isOutgoing = rel.relationship.fromConceptId.toString() === selectedConcept.id;
                        // Skip self-referential relationships
                        if (rel.relationship.fromConceptId.toString() === rel.relationship.toConceptId.toString()) {
                          return null;
                        }
                        return (
                          <li key={rel.relationship.id} className="relationship">
                            <div className="relationship-type">
                              {getRelationshipTypeName(rel.relationship.relationshipTypeId)}
                            </div>
                            <div className="relationship-target">
                              {isOutgoing ? 
                                getConceptName(concepts, rel.relationship.toConceptId) :
                                `${getConceptName(concepts, rel.relationship.fromConceptId)} ${getRelationshipTypeName(rel.relationship.relationshipTypeId)} ${selectedConcept.name}`
                              }
                            </div>
                            <div className="relationship-probability">
                              P: {formatProbability(rel.relationship.probability)}
                              <span className="relationship-confidence">
                                C: {formatProbability(rel.relationship.confidence)}
                              </span>
                            </div>
                            <div className="relationship-creator">
                              Created by: {rel.relationship.creator.principalId.toString().slice(0, 10)}...
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
                        );
                      })}
                    </ul>
                  </div>
                </div>
              ) : (
                <div className="no-selection">
                  <p>Select a concept to view details</p>
                </div>
              )}
            </div>
          </>
        ) : (
          <div className="login-prompt">
            <h2>Welcome to Think Bench</h2>
            <p>Please login with Internet Identity to start managing concepts and relationships.</p>
            <button onClick={login} className="auth-button">Login with Internet Identity</button>
          </div>
        )}
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
