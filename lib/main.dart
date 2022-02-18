import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Reveal',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FocusNode focusNode = FocusNode();
  final PageController horizontalController = PageController();
  final List<PageController> verticalControllers = [];
  List<List<String>> markdownPages = [];

  @override
  void initState() {
    super.initState();

    markdownPages = slidify(markdownSource1);

    for (var _ in markdownPages) {
      verticalControllers.add(PageController());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      autofocus: true,
      child: Focus(
        autofocus: true,
        canRequestFocus: true,
        onKey: (data, event) {
          if (event.isKeyPressed(LogicalKeyboardKey.space) ||
              event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
            moveSlide();

            return KeyEventResult.handled;
          } else if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
            moveSlide(back: true);

            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          body: Center(
            child: PageView.builder(
              controller: horizontalController,
              itemCount: markdownPages.length,
              itemBuilder: (BuildContext context, int index) {
                var pages = markdownPages[index];

                return PageView.builder(
                  controller: verticalControllers[index],
                  scrollDirection: Axis.vertical,
                  itemCount: pages.length,
                  itemBuilder: (BuildContext context, int innerIndex) {
                    String markdown = pages[innerIndex];

                    return Markdown(data: markdown);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void moveSlide({bool back = false}) {
    int horzPos = horizontalController.page?.toInt() ?? 0;
    bool startOfHorzController = horzPos == 0;
    bool endOfHorzController = horzPos == markdownPages.length - 1;

    var verticalController = verticalControllers[horzPos];
    int vertPos = verticalController.page?.toInt() ?? 0;
    bool startOfVertController = vertPos == 0;
    bool endOfVertController = vertPos == markdownPages[horzPos].length - 1;

    if (endOfVertController) {
      if (!back) {
        if (!endOfHorzController) {
          horizontalController.animateToPage(horzPos + 1,
              duration: const Duration(seconds: 1), curve: Curves.ease);
        }
      } else {
        if (!startOfVertController) {
          verticalController.animateToPage(vertPos - 1,
              duration: const Duration(seconds: 1), curve: Curves.ease);
        } else {
          if (!startOfHorzController) {
            horizontalController.animateToPage(horzPos - 1,
                duration: const Duration(seconds: 1), curve: Curves.ease);
          }
        }
      }
    } else {
      if (!back) {
        verticalController.animateToPage(vertPos + 1,
            duration: const Duration(seconds: 1), curve: Curves.ease);
      } else {
        if (!startOfVertController) {
          verticalController.animateToPage(vertPos - 1,
              duration: const Duration(seconds: 1), curve: Curves.ease);
        } else {
          if (!startOfHorzController) {
            horizontalController.animateToPage(horzPos - 1,
                duration: const Duration(seconds: 1), curve: Curves.ease);
          }
        }
      }
    }
  }

  List<List<String>> slidify(markdown, {Options? options}) {
    options = getSlidifyOptions(options);

    var separatorRegex = RegExp(
        options.separator +
            (options.verticalSeparator.isNotEmpty
                ? '|' + options.verticalSeparator
                : ''),
        multiLine: true),
        horizontalSeparatorRegex = RegExp(options.separator);

    Iterable<RegExpMatch> matches;
    int lastIndex = 0;
    bool isHorizontal;
    bool wasHorizontal = true;
    String content = '';
    List<List<String>> sectionStack = <List<String>>[];

    // iterate until all blocks between separators are stacked up
    while (
    (matches = separatorRegex.allMatches(markdown, lastIndex)).isNotEmpty) {
      //var notes = null;

      // determine direction (horizontal by default)
      isHorizontal =
          horizontalSeparatorRegex.hasMatch(matches.first.group(0) ?? '');

      if (!isHorizontal && wasHorizontal) {
        // create vertical stack
        sectionStack.add(<String>[]);
      }

      // pluck slide content from markdown input
      content = markdown.substring(lastIndex, matches.first.start);

      if (isHorizontal && wasHorizontal) {
        // add to horizontal stack
        sectionStack.add([content]);
      } else {
        // add to vertical stack
        sectionStack[sectionStack.length - 1].add(content);
      }

      lastIndex = matches.first.end;
      wasHorizontal = isHorizontal;
    }

    // add the remaining slide
    String rest = markdown.substring(lastIndex);
    if (wasHorizontal) {
      sectionStack.add([rest]);
    } else {
      sectionStack[sectionStack.length - 1].add(rest);
    }

    // remove empty slides
    for (var element in sectionStack) {
      element.removeWhere((element) => element.isEmpty);
    }
    sectionStack.removeWhere((List<String> element) => element.isEmpty);

    return sectionStack;

    // var markdownSections = '';
    //
    // // flatten the hierarchical stack, and insert <section data-markdown> tags
    // for( var i = 0, len = sectionStack.length; i < len; i++ ) {
    //   // vertical
    //   if( sectionStack[i] instanceof Array ) {
    //     markdownSections += '<section '+ options.attributes +'>';
    //
    //     sectionStack[i].forEach( function( child ) {
    //     markdownSections += '<section data-markdown>' + createMarkdownSlide( child, options ) + '</section>';
    //     } );
    //
    //     markdownSections += '</section>';
    //   }
    //   else {
    //     markdownSections += '<section '+ options.attributes +' data-markdown>' + createMarkdownSlide( sectionStack[i], options ) + '</section>';
    //   }
    // }
    //
    // return markdownSections;
  }

  static const defaultSlideSeparator = '\r?\n---\r?\n',
      defaultNotesSeparator = 'notes?:',
      defaultVerticalSeparator = '\r?\n\r?\n';

  Options getSlidifyOptions(Options? options) {
    options ??= Options();
    options.separator = options.separator.isNotEmpty
        ? options.separator
        : defaultSlideSeparator;
    options.notesSeparator = options.notesSeparator.isNotEmpty
        ? options.notesSeparator
        : defaultNotesSeparator;
    options.verticalSeparator = options.verticalSeparator.isNotEmpty
        ? options.verticalSeparator
        : defaultVerticalSeparator;

    return options;
  }
}

class Options {
  String separator = '';
  String notesSeparator = '';
  String attributes = '';
  String verticalSeparator = '';
}

const String markdownSource1 = '''
Page 1

Page 1.1

Page 1.2
---
Page 2

Page 2.1

Page 2.2
---
Page 3

Page 3.1

Page 3.2
''';

const String markdownSource2 = '''
Page 1
---
Page 2

Page 2.1
---
Page 3

Page 3.1

Page 3.2
''';

const String markdownSource3 = '''
Page 1

Page 1.1

Page 1.2
---
Page 2

Page 2.1
---
Page 3
''';
