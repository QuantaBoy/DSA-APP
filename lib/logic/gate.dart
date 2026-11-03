import 'package:flutter/painting.dart';

/// GATE Data Science & AI (DA) syllabus as a journey: sections in study order, each with its subtopics.
/// Questions for a subtopic are aptitude-style cards tagged `gate:<subtopic id>`.

typedef GateTopic = ({String id, String name});

class GateSection {
  const GateSection(this.id, this.name, this.color, this.topics);
  final String id;
  final String name;
  final Color color;
  final List<GateTopic> topics;
}

const gateDa = [
  GateSection('prob', 'Probability & Statistics', Color(0xFF6C4EF5), [
    (id: 'prob-count', name: 'Counting: permutations & combinations'),
    (id: 'prob-axioms', name: 'Axioms, sample space, events'),
    (id: 'prob-cond', name: 'Conditional & joint probability, Bayes'),
    (id: 'prob-desc', name: 'Mean, median, mode, std dev, correlation'),
    (id: 'prob-rv', name: 'Random variables, expectation, variance'),
    (id: 'prob-discrete', name: 'Discrete distributions: uniform, Bernoulli, binomial'),
    (id: 'prob-continuous', name: 'Continuous: exponential, Poisson, normal, t, chi²'),
    (id: 'prob-clt', name: 'CDF, central limit theorem'),
    (id: 'prob-tests', name: 'Confidence intervals, z, t, chi² tests'),
  ]),
  GateSection('linalg', 'Linear Algebra', Color(0xFF0EA5E9), [
    (id: 'la-spaces', name: 'Vector spaces, subspaces, independence'),
    (id: 'la-matrices', name: 'Projection, orthogonal, idempotent matrices'),
    (id: 'la-quadratic', name: 'Partition matrices, quadratic forms'),
    (id: 'la-systems', name: 'Linear systems, Gaussian elimination'),
    (id: 'la-eigen', name: 'Eigenvalues & eigenvectors'),
    (id: 'la-rank', name: 'Determinant, rank, nullity, projections'),
    (id: 'la-decomp', name: 'LU decomposition, SVD'),
  ]),
  GateSection('calc', 'Calculus & Optimization', Color(0xFF10B981), [
    (id: 'calc-limits', name: 'Limits, continuity, differentiability'),
    (id: 'calc-taylor', name: 'Taylor series'),
    (id: 'calc-extrema', name: 'Maxima & minima'),
    (id: 'calc-opt', name: 'Single-variable optimization'),
  ]),
  GateSection('prog', 'Programming, DS & Algorithms', Color(0xFFF59E0B), [
    (id: 'pg-python', name: 'Programming in Python'),
    (id: 'pg-ds', name: 'Stacks, queues, linked lists, trees, hash tables'),
    (id: 'pg-search', name: 'Linear & binary search'),
    (id: 'pg-sort', name: 'Selection, bubble, insertion sort'),
    (id: 'pg-dc', name: 'Divide & conquer: mergesort, quicksort'),
    (id: 'pg-graphs', name: 'Graph theory, traversals, shortest paths'),
  ]),
  GateSection('db', 'Databases & Warehousing', Color(0xFFEC4899), [
    (id: 'db-er', name: 'ER model, relational model'),
    (id: 'db-algebra', name: 'Relational algebra, tuple calculus'),
    (id: 'db-sql', name: 'SQL, integrity constraints'),
    (id: 'db-normal', name: 'Normal forms'),
    (id: 'db-files', name: 'File organization, indexing'),
    (id: 'db-transform', name: 'Data types, normalization, discretization, sampling'),
    (id: 'db-warehouse', name: 'Warehouse schemas, concept hierarchies, measures'),
  ]),
  GateSection('ml', 'Machine Learning', Color(0xFFEF4444), [
    (id: 'ml-regression', name: 'Linear, multiple & ridge regression'),
    (id: 'ml-logistic', name: 'Logistic regression, kNN, naive Bayes'),
    (id: 'ml-lda-svm', name: 'LDA, support vector machines'),
    (id: 'ml-trees', name: 'Decision trees'),
    (id: 'ml-bias', name: 'Bias-variance, cross-validation (LOO, k-fold)'),
    (id: 'ml-nn', name: 'MLP, feed-forward neural networks'),
    (id: 'ml-cluster', name: 'k-means, k-medoid, hierarchical clustering'),
    (id: 'ml-pca', name: 'Dimensionality reduction, PCA'),
  ]),
  GateSection('ai', 'Artificial Intelligence', Color(0xFF8B5CF6), [
    (id: 'ai-search', name: 'Search: uninformed, informed, adversarial'),
    (id: 'ai-logic', name: 'Propositional & predicate logic'),
    (id: 'ai-uncertainty', name: 'Conditional independence, variable elimination'),
    (id: 'ai-sampling', name: 'Approximate inference by sampling'),
  ]),
  GateSection('ga', 'General Aptitude', Color(0xFF64748B), [
    (id: 'ga-verbal', name: 'Verbal ability'),
    (id: 'ga-quant', name: 'Quantitative aptitude'),
    (id: 'ga-reasoning', name: 'Analytical reasoning'),
    (id: 'ga-spatial', name: 'Spatial aptitude'),
  ]),
];

const _prefix = 'gate:';

/// The card topic for a GATE subtopic, and back.
String gateTag(String topicId) => '$_prefix$topicId';
String? gateTopicOf(String cardTopic) => cardTopic.startsWith(_prefix) ? cardTopic.substring(_prefix.length) : null;
bool isGateCard(String cardTopic) => cardTopic.startsWith(_prefix);

final _byId = {
  for (final s in gateDa)
    for (final t in s.topics) t.id: (section: s, topic: t),
};

({GateSection section, GateTopic topic})? gateLookup(String topicId) => _byId[topicId];

int get gateTopicCount => _byId.length;

/// Share of [section]'s subtopics in [covered], 0..1.
double sectionProgress(GateSection section, Set<String> covered) =>
    section.topics.where((t) => covered.contains(t.id)).length / section.topics.length;

/// The subtopic to study next: the first uncovered one in syllabus order, or null when all are covered.
GateTopic? nextGateTopic(Set<String> covered) => [for (final s in gateDa) ...s.topics].where((t) => !covered.contains(t.id)).firstOrNull;
