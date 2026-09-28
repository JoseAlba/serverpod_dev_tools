import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// Endpoint for seeding and managing development database records for [Author] and [Article].
///
/// Can be invoked directly from the Serverpod DevTools "Endpoint Explorer & Caller",
/// via the HTTP suite (`http/seed.http`), or from the CLI script (`bin/seed.dart`).
class SeedEndpoint extends Endpoint {
  /// Seeds realistic authors and articles into the development database.
  ///
  /// If [clearExisting] is true, deletes previously seeded articles and authors first.
  Future<SeedResult> seedSampleData(
    Session session, {
    bool clearExisting = false,
  }) async {
    if (clearExisting) {
      await Article.db.deleteWhere(session, where: (t) => t.id.notEquals(null));
      await Author.db.deleteWhere(session, where: (t) => t.id.notEquals(null));
    }

    // 1. Insert Authors
    final ada = await Author.db.insertRow(
      session,
      Author(
        name: 'Ada Lovelace',
        email: 'ada.lovelace@analytical.org',
        bio: 'Mathematician and writer, pioneer of computer algorithms and symbolic computing.',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    );

    final alan = await Author.db.insertRow(
      session,
      Author(
        name: 'Alan Turing',
        email: 'alan.turing@manchester.ac.uk',
        bio: 'Father of theoretical computer science, cryptography, and artificial intelligence.',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
    );

    final grace = await Author.db.insertRow(
      session,
      Author(
        name: 'Grace Hopper',
        email: 'grace.hopper@usnavy.mil',
        bio: 'Computer scientist and naval officer who invented the compiler and coined the term "debugging".',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    );

    final authors = [ada, alan, grace];

    // 2. Insert Articles with valid foreign keys referencing the authors
    final articles = <Article>[
      Article(
        title: 'Sketch of the Analytical Engine: Note G',
        content: 'Formulation of the first machine algorithm for calculating Bernoulli numbers using punch cards.',
        published: true,
        authorId: ada.id!,
        createdAt: DateTime.now().subtract(const Duration(days: 28)),
      ),
      Article(
        title: 'The Science of Operations and General Symbolic Logic',
        content: 'How computing machines can act on other things besides numbers, including music and language.',
        published: true,
        authorId: ada.id!,
        createdAt: DateTime.now().subtract(const Duration(days: 25)),
      ),
      Article(
        title: 'On Computable Numbers, with an Application to the Entscheidungsproblem',
        content: 'Introducing the universal computing machine, the halting problem, and limits of computability.',
        published: true,
        authorId: alan.id!,
        createdAt: DateTime.now().subtract(const Duration(days: 18)),
      ),
      Article(
        title: 'Computing Machinery and Intelligence: The Imitation Game',
        content: 'Can machines think? Proposing behavioral benchmarks for assessing artificial intelligence.',
        published: true,
        authorId: alan.id!,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      Article(
        title: 'The Education of a Computer: Compilers and the A-0 System',
        content: 'Why programmers should write programs in pseudocode and have computers translate to machine code.',
        published: true,
        authorId: grace.id!,
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
      ),
      Article(
        title: 'FLOW-MATIC and Higher-Level Business Languages',
        content: 'Pioneering human-readable English statements for business data processing.',
        published: false,
        authorId: grace.id!,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    for (final article in articles) {
      await Article.db.insertRow(session, article);
    }

    session.log(
      'Seeded ${authors.length} authors and ${articles.length} articles into database.',
      level: LogLevel.info,
    );

    return SeedResult(
      message: 'Successfully seeded database with authors and articles.',
      authorsCreated: authors.length,
      articlesCreated: articles.length,
      success: true,
    );
  }

  /// Clears all authors and articles from the database.
  Future<SeedResult> clearSampleData(Session session) async {
    final deletedArticles = await Article.db.deleteWhere(
      session,
      where: (t) => t.id.notEquals(null),
    );
    final deletedAuthors = await Author.db.deleteWhere(
      session,
      where: (t) => t.id.notEquals(null),
    );

    return SeedResult(
      message: 'Cleared all authors and articles from the database.',
      authorsCreated: deletedAuthors.length,
      articlesCreated: deletedArticles.length,
      success: true,
    );
  }

  /// Returns the current count of authors and articles in the database.
  Future<SeedResult> getDatabaseStats(Session session) async {
    final authors = await Author.db.find(session);
    final articles = await Article.db.find(session);

    return SeedResult(
      message: 'Current database counts.',
      authorsCreated: authors.length,
      articlesCreated: articles.length,
      success: true,
    );
  }
}
