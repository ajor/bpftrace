#include <regex>

#include "printf.h"

namespace bpftrace {

std::string verify_format_string(const std::string &fmt, std::vector<SizedType> args)
{
  std::stringstream message;
  std::regex re("%-?[0-9]*[a-zA-Z]");

  auto tokens_begin = std::sregex_iterator(fmt.begin(), fmt.end(), re);
  auto tokens_end = std::sregex_iterator();

  auto num_tokens = std::distance(tokens_begin, tokens_end);
  int num_args = args.size();
  if (num_args < num_tokens)
  {
    message << "printf: Not enough arguments for format string (" << num_args
            << " supplied, " << num_tokens << " expected)" << std::endl;
    return message.str();
  }
  if (num_args > num_tokens)
  {
    message << "printf: Too many arguments for format string (" << num_args
            << " supplied, " << num_tokens << " expected)" << std::endl;
    return message.str();
  }

  auto token_iter = tokens_begin;
  for (int i=0; i<num_args; i++, token_iter++)
  {
    Type arg_type = args.at(i).type;
    if (arg_type == Type::sym || arg_type == Type::usym)
      arg_type = Type::string; // Symbols should be printed as strings
    int offset = 1;

    // skip over format widths during verification
    if (token_iter->str()[offset] == '-')
      offset++;
    while (token_iter->str()[offset] >= '0' && token_iter->str()[offset] <= '9')
      offset++;

    char token = token_iter->str()[offset];

    Type token_type;
    switch (token)
    {
      case 'd':
      case 'u':
      case 'x':
      case 'X':
      case 'p':
        token_type = Type::integer;
        break;
      case 's':
        token_type = Type::string;
        break;
      default:
        message << "printf: Unknown format string token: %" << token << std::endl;
        return message.str();
    }

    if (arg_type != token_type)
    {
      message << "printf: %" << token << " specifier expects a value of type "
              << token_type << " (" << arg_type << " supplied)" << std::endl;
      return message.str();
    }
  }
  return "";
}

} // namespace bpftrace
