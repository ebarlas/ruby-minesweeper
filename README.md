# Minesweeper

Microsoft Minesweeper is a grid-based bomb-avoidance game that was included
in the Windows operating systems of my childhood: Windows 3.1, Windows 95, Windows 98,
Windows ME, and Windows XP.

## Ruby

Ruby is a delightful language for implementing Minesweeper!

The [Gosu](https://www.libgosu.org/) 2D game development library is a perfect fit.
Image rendering is effortless and working with the game loop couldn't be simpler.

## Assets

The PNG bitmap [images](images/) are rasterized from SVG source files that
I drafted based on screenshots of the Windows 98 edition of the game.

![tile](images/tile.png) ![tile 0](images/tile_0.png) ![tile 1](images/tile_1.png) ![tile 2](images/tile_2.png) ![tile 3](images/tile_3.png) ![tile 4](images/tile_4.png) ![tile 5](images/tile_5.png) ![tile 6](images/tile_6.png) ![tile 7](images/tile_7.png) ![tile 8](images/tile_8.png) ![tile mine](images/tile_mine.png) ![tile flag](images/tile_flag.png)

![digit 0](images/digit_0.png) ![digit 1](images/digit_1.png) ![digit 2](images/digit_2.png) ![digit 3](images/digit_3.png) ![digit 4](images/digit_4.png) ![digit 5](images/digit_5.png) ![digit 6](images/digit_6.png) ![digit 7](images/digit_7.png) ![digit 8](images/digit_8.png) ![digit 9](images/digit_9.png) ![digit panel](images/digit_panel.png)

![face win](images/face_win.png) ![face playing](images/face_playing.png) ![face lose](images/face_lose.png)

![background medium](images/background_medium.png)

## Play

- Left click (covered) - reveal tile
- Left click (revealed) - reveal neighbors if adjacent flag-count equals mine-count
- Right click (covered) - flag tile

```
ruby minesweeper.rb -h
Usage: minesweeper [options]
    -b, --beginner                   Start game in Beginner mode
    -i, --intermediate               Start game in Intermediate mode
    -e, --expert                     Start game in Expert mode
    -h, --help                       Show this help message
```