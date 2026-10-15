import Foundation

/// Bundled example pixel-color formulas (PRD FR-10). `sample` is the exact text a user can
/// paste — prose, LaTeX layout macros and all — so it doubles as the parser's fixture.
nonisolated enum PixelFormulaSamples {
    static let sampleTitle = "예시 픽셀 수식 (2000 × 1200)"

    static let sample = #"""
    The above picture is a converted version of a 2000 × 1200 image.
    For m = 1, 2, 3, …, 2000 and n = 1, 2, 3, …, 1200, the color of the pixel
    of the row n and the column m is

    \mathrm{rgb}\Big( F\big(H_0(\tfrac{m-1000}{500}, \tfrac{601-n}{500})\big),\;
    F\big(H_1(\tfrac{m-1000}{500}, \tfrac{601-n}{500})\big),\;
    F\big(H_2(\tfrac{m-1000}{500}, \tfrac{601-n}{500})\big) \Big),

    where

    F(x) = \left\lfloor 255\, e^{-e^{-1000x}}\, |x|^{\,e^{-e^{1000(x-1)}}} \right\rfloor,  and

    H_v(x,y) = e^{-e^{-50\left(y-\frac{x}{3}-\frac{7}{50}\right)}} \frac{B(x,y)}{5}
     + \frac{20K_v(x,y)}{37}
     \left( 1 - e^{-e^{200\left(\left(x+\frac{y}{3}+\frac{3}{2}\right)^2 + \left(y-\frac{x}{3}+\frac{3}{100}\right)^2 - \frac{3}{100}\right)}}
     - e^{-200\left(y-\frac{x}{3}+5\sqrt{\left|\frac{3}{100}-\left(x+\frac{y}{3}+\frac{3}{2}\right)^2\right|}\right)} \right)
     \left( 1 - e^{-e^{200\left(\left(x+\frac{y}{3}-\frac{1}{2}\right)^2 + \left(y-\frac{x}{3}+\frac{3}{100}\right)^2 - \frac{1}{50}\right)}}
     - e^{-200\left(y-\frac{x}{3}+5\sqrt{\left|\frac{1}{50}-\left(x+\frac{y}{3}-\frac{1}{2}\right)^2\right|}\right)} \right),

    B(x,y) = \sum_{s=1}^{50} e^{\,-e^{-100\left(\sin^6(T_s(x,y)) - \frac{199}{200}\right)}
     - e^{-\frac{\cos^6(200T_s(x,y)+s^2)}{20}}
     - e^{1000\left(\left|x+\frac{y}{3}\right| - \frac{7}{10}\right)}},

    T_s(x,y) = \pi\frac{3x+y}{3} + \frac{7+5\cos(s^2)}{35}\left(y-\frac{x}{3}\right)^2
     \cos\left( (6+3\cos(4s^2))\frac{3y-x}{3} + 2\cos(4y+2x+5s^2) + 3s^2 \right),

    K_v(x,y) = \sum_{s=1}^{50} \left(\frac{19}{20}\right)^s
     \left( \frac{3}{2} + \frac{1}{2}(v-1)^2 + \frac{4-4v}{10}\cos(s^2) \right)
     e^{-e^{-\frac{3}{2}\left( \cos\left(\left(\frac{5}{4}\right)^s L_{1,s}(x,y)\right)
     + \cos\left(3\left(\frac{5}{4}\right)^s L_{3,s}(x,y)\right) + 2\cos(32s^2) \right)
     \cos\left( \left(\frac{5}{4}\right)^s \left(\sin(s^2)U(x,y) - \frac{3}{2}\cos(s^2)V(x,y)\right)
     + \cos\left(3\left(\frac{5}{4}\right)^s L_{5,s}(x,y)\right) + 2\cos(12s^2) \right)
     - \frac{3}{2} + A_s(x,y)}},

    A_s(x,y) = e^{-e^{\frac{1}{2}\sqrt{\left(x+\frac{y}{3}-\frac{1}{2}\right)^2 + 6\left(y-\frac{x}{3}\right)^2}
     \sqrt{\left(x+\frac{y}{3}+\frac{1}{2}\right)^2 + 6\left(y-\frac{x}{3}\right)^2}\,
     \left|U(x,y)+\cos^4(7s^2)\right| - \frac{7}{20}}}
     + e^{-e^{10\left(\left(x+\frac{y}{3}+\frac{1}{2}\right)^2 + 6\left(y-\frac{x}{3}\right)^2 - \frac{3}{100}\right)}}
     + e^{-e^{10\left(\left(x+\frac{y}{3}-\frac{1}{2}\right)^2 + 6\left(y-\frac{x}{3}\right)^2 - \frac{3}{100}\right)}},

    L_{u,s}(x,y) = \cos(us^2)\,U(x,y) + \frac{3}{2}\sin(us^2)\,V(x,y),

    U(x,y) = \cos\left(2\ln\left((Q(x,y))^2 + (P(x,y))^2\right)\right) Q(x,y)
     + \sin\left(2\ln\left((Q(x,y))^2 + (P(x,y))^2\right)\right) P(x,y),

    V(x,y) = \arctan\left( \frac{Q(x,y)}{|P(x,y)|} \right),

    P(x,y) = \frac{3y-x}{3}\left(
     \frac{3}{2\left(x+\frac{y}{3}+\frac{1}{2}\right)^2 + 12\left(y-\frac{x}{3}\right)^2 + \frac{1}{10^5}}
     + \frac{1}{\left(x+\frac{y}{3}-\frac{1}{2}\right)^2 + 6\left(y-\frac{x}{3}\right)^2 + \frac{1}{10^5}} \right),

    Q(x,y) = \frac{3x+y+\frac{3}{2}}{2\left(x+\frac{y}{3}+\frac{1}{2}\right)^2 + 12\left(y-\frac{x}{3}\right)^2 + \frac{1}{10^5}}
     + \frac{x+\frac{y}{3}-\frac{1}{2}}{\left(x+\frac{y}{3}-\frac{1}{2}\right)^2 + 6\left(y-\frac{x}{3}\right)^2 + \frac{1}{10^5}}.
    """#
}
