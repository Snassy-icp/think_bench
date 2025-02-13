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

  // Load concepts on mount
  useEffect(() => {
    loadConcepts();
  }, []);

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
      const result = await think_bench_backend.inferRelationships({
        startingConcept: conceptId,
        relationshipType: [],  // Optional: none
        maxDepth: [3],        // Optional: some(3)
        minProbability: [],   // Optional: none
      });
      if ('ok' in result) {
        setRelationships(result.ok.items);
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
    setSelectedConcept(concept);
    loadRelationships(concept.id);
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
                  key={concept.id}
                  className={selectedConcept?.id === concept.id ? 'selected' : ''}
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
                        {getConceptName(rel.relationship.toConceptId)}
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
  return types[typeId] || `Type ${typeId}`;
}

function getConceptName(conceptId) {
  // TODO: Implement concept name lookup
  return `Concept ${conceptId}`;
}

function formatProbability(prob) {
  return `${prob.numerator}/${prob.denominator}`;
}

export default App;
