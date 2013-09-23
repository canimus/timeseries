var gdtw = function (measure, s, o) {
  var pathlength = 1;
  var res = measure(s[0], o[0]);
  while (s.length > 1 && o.length > 1) {
    // find minimum
    var left = measure(s[1], o[0]);
    var middle = measure(s[1], o[1]);
    var right = measure(s[0], o[1]);
    var min = Math.min(left, middle, right);
    switch (min) {
      case left:
        s = _.rest(s);
        res += left;
        break;
      case right:
        o = _.rest(o);
        res += right;
        break;
      default: // middle
        s = _.rest(s);
        o = _.rest(o);
        res += middle;
    }
    pathlength += 1;
  }
  // here o or s is size 1
  // swap if o is
  if (o.length === 1) {
    temp = o; o = s; s = temp;
  }
  if (o.length !== 1) {
    // match everything to first of s
    for (var i=1; i < o.length; i++) {
      res += measure(s[0], o[i]);
      pathlength += 1;        
    }
  }
  return res/pathlength;
}